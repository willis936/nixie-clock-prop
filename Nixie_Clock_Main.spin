{{ Nixie_Clock_Main.spin

Authors:
Terry Willis
Paul  Willis

Date:
March 7, 2017

Notes:
To program plug in prop. plug, run Parallax Serial
Terminal, use COM port 3, Baud rate 115200, then
hit F11 (compile/load EEPROM) in the prop tool

Dipswitches 1-5 are used to set the UTC Offset.
  BCD starting at -12 going up to +20 (anything above +14 is clipped).
Dipswitch 6 is used to enable/disable DST.
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  nibble = 4
  lsnibble = $f
  dispdp = $80
  lonedp = $8f
  
  ' Flag Masks
  isEnabled  = %0001  ' Display ENABLE flag
  flgPrint   = %0010  ' Print to terminal flag
  flgDirect  = %0100  ' Direct Drive mode flag
  flgDST     = %1000  ' DST checking flag
  
' Pin Assignments
  C_DIG0        = 0
  C_DIG1        = 1
  C_DIG2        = 2
  C_DIG3        = 3
  C_DIG4        = 4
  C_DIG5        = 5
  C_DIG6        = 6
  C_DIG7        = 7
  C_DIG8        = 8
  C_DIG9        = 9
  C_LHDP        = 16
  
  A_HR10        = 10
  A_HR1         = 11
  A_MN10        = 12
  A_MN1         = 13
  A_SC10        = 14
  A_SC1         = 15
  
  DIPSW1        = 17
  DIPSW2        = 18
  DIPSW3        = 19
  DIPSW4        = 20
  DIPSW5        = 21
  DIPSW6        = 22
  HVPS_ENB      = 24
  
  GPS_RX        = 26
  GPS_PPS       = 27
  
  RTC_32k       = 25
  
  COM_TX        = 30
  COM_RX        = 31
  
  ' Terminal formmatting control
  #1, HOME, GOTOXY, #8, BKSP, TAB, LF, CLREOL, CLRDN, CR
  #14, GOTOX, GOTOY, CLS
  
  ' refresh rate controls max accuracy.
  ' setting too high causes bleed because driver has capacitance
  ' If we loop 720 times a second, 6 digits: 720 / 6 = 120 Hz
  ' 720*(1/720 - 20 us to turn off digit) / 6 = 16.4% duty cycle
  ' 6/720 = 8.3 ms accuracy
  '   720: (120  Hz 16.4% duty cycle, 8.3 ms accuracy)
  '  1024: (171  Hz 16.3% duty cycle, 5.9 ms accuracy)
  '  1440: (240  Hz 16.2% duty cycle, 4.1 ms accuracy)
  '  2048: (341  Hz 16.0% duty cycle, 2.9 ms accuracy)
  '  2880: (480  Hz 15.7% duty cycle, 2.1 ms accuracy)
  '  4096: (682  Hz 15.3% duty cycle, 1.5 ms accuracy)
  '  4320: (720  Hz 15.2% duty cycle, 1.4 ms accuracy)
  '  5760: (960  Hz 14.7% duty cycle, 1.0 ms accuracy)
  '  6144: (1024 Hz 14.6% duty cycle, 1.0 ms accuracy)
  '  7200: (1200 Hz 14.3% duty cycle, 0.8 ms accuracy)
  ' 11520: (1920 Hz 10.2% duty cycle, 0.5 ms accuracy)
  ' 36000: (6000 Hz  4.7% duty cycle, 0.2 ms accuracy)
  refreshRate = 2048

OBJ
  RTCEngine     : "RTCEngine"
  gps           : "gps_basic"
  term          : "FullDuplexSerialPlus"
  fstring       : "string.float"
  fmath         : "tiny.math.float"
  weekdaycalc   : "DayOfTheWeek"
  ASCII         : "ASCII0_STREngine_1"

VAR
  byte cmd, out
  byte data[12]
  long LowCharPin, HighCharPin        ' The pins for specifying chars.
  long DPPin                          ' The pins for specifying chars.
  long Seg0Pin, Seg9Pin               ' The pins for the segments.
  long LowUTCPin, HighUTCPin          ' The pins for specifying the UTC offset in hours.
  long DSTPin                         ' The pin  for specifying DST checking.
  long flags
  long runningCogID
  long stack[50]
  long UTCOffset, UTCTemp, localTimeGPS
  long RTCfreq, RTCmax
  long updatetime
  byte hrs, mns, secs
  byte days, mons, yrs, dayofwk
  byte SemID
  byte DST, century, gpsfix
  
  byte   DspBuff[6]             ' 6 byte display buffer
  byte   DspBuff1[6]            ' 6 byte display buffer1

PUB main| i,c
  
  LowCharPin  := 10
  HighCharPin := 15   ' The pins for specifying chars.
  Seg0Pin     := 0
  Seg9Pin     := 9    ' The pins for the segments.
  DPPin       := 16   ' The pin  for the decimal point.
  LowUTCPin   := DIPSW1 ' The pins for specifying the UTC offset in hours.
  HighUTCPin  := DIPSW5
  DSTPin      := DIPSW6 ' Pin to toggle DST checking
  UTCOffset   := -5   ' Hard code the UTC offset for now...
  UTCTemp     := 0    ' Default new UTC value
  century     := 20   ' Assume the clock was booted in 20XX
  RTCfreq     := 32768' How many clock edges to count per second
  RTCmax      := RTCfreq+1 ' wait one RTC cycle before assuming the PPS isn't coming
  SemID       := locknew
  
  dira[HVPS_ENB]~~        ' Enable high voltage
  outa[HVPS_ENB]~~
  
  dira[GPS_PPS]~          ' Set PPS pin to input
  dira[RTC_32k]~          ' Set 32k pin to input
  
  ctra[30..26] := %01010  ' Set up counter for counting positive edges
  ctra[5..0]   := RTC_32k ' Monitor the 32k pin
  frqa         := 1       ' Add 1 to phsa register for every clock tick
  phsa         := 0       ' Clear counter register
  
  dira[HighUTCPin..LowUTCPin]~  ' Set UTC Offset dipswitch pins to input
  dira[DSTPin]~                 ' Set DST enable pin to input
  
  ' Adjust how many digits are shown
  fstring.SetPrecision(4)
  
  ' Initialize 32kHz output from RTC
  RTCEngine.setStatus(%0000_1000)
  ' Configure RTC behavior
  RTCEngine.setControl(%0000_0100)
  
  ' GPS serial port setup
  gps.startx(GPS_RX, UTCOffset, 9600, 1250)
  
  term.start(COM_RX, COM_TX, 0, 115200)
  clearterm
  term.Str(String("Paul's Nixie Clock"))
  term.tx(CLREOL)
  term.tx(LF)
  term.tx(CLREOL)
  
  secs := RTCEngine.getSeconds
  if secs == 80  ' Converted from binary to bcd
    ' The clock has not been initialized so let's set it
    ' This will demonstrate hour & day roleover.
    setdate
    settime
  
  bytefill(@DspBuff1, $0, 6)
  flags := isEnabled
  runningCogID := cognew(ShowDig, @stack) + 1   ' start the display driver cog
  
  term.tx(LF)
  term.Str(String("D = setdate, T = settime, S = show time"))
  term.tx(CLREOL)
  term.tx(LF)
  term.tx(CLREOL)
  
  ' main loop
  repeat
    ' check if console interface should be displayed
    c := uppercase(term.rxcheck)
    if c == "D"
      term.GetDec   ' Ignore the return used to enter "D"
      setdate
    if c == "T"
      term.GetDec   ' Ignore the return used to enter "T"
      settime
    if c == "S"
      term.GetDec   ' Ignore the return used to enter "S"
      flags ^= flgPrint
    
    ' Check if it is a new second
    gpsfix := gps.n_gpsfix
    {{'Debug swap time source
    if secs // 20 < 10
      gpsfix := 0
    '}}
    
    if gpsfix > 0
      ' Get the date
      yrs  := gps.n_year
      mons := gps.n_month
      days := gps.n_day
      dayofwk := weekdaycalc.DOTW((century*100)+yrs, mons, days)+1
      ' Get the time
      localTimeGPS := ASCII.decimalToInteger(gps.s_local_time)
      hrs  := (localTimeGPS / 10000) // 100
      mns  := (localTimeGPS / 100)   // 100
      secs := (localTimeGPS          // 100)
      
      ' Get the time, assume you just read the data for the next second
      ' Assuming data is from one second ago, take care of time rollover
      repeat i from 1 to 2
        secs += 1
        if secs > 59
          mns  += 1
          secs := 0
        if mns > 59
          hrs  += 1
          mns  := 0
        if hrs > 23
          hrs  := 0
        elseif i == 2
          
          ' Only update the date when not rolling over a day
          RTCEngine.setYear((century*100)+yrs)
          RTCEngine.setMonth(mons)
          RTCEngine.setDate(days)
          RTCEngine.setDay(dayofwk)
      
      ' update the RTC when there is a GPS fix
      RTCEngine.setHours(hrs)
      RTCEngine.setMinutes(mns)
    else
      ' get the date
      yrs     := RTCEngine.getYear
      mons    := RTCEngine.getMonth
      days    := RTCEngine.getDate
      dayofwk := RTCEngine.getDay
      ' get the time
      hrs  := RTCEngine.getHours
      mns  := RTCEngine.getMinutes
      secs := RTCEngine.getSeconds
      
      repeat i from 1 to 1
        secs += 1
        if secs > 59
          mns  += 1
          secs := 0
        if mns > 59
          hrs  += 1
          mns  := 0
        if hrs > 23
          hrs  := 0
    
    ' check if it's a new century!
    if yrs == 0
      if mons == 1
        if days == 1
          if hrs == 0
            if mns == 0
              if secs == 0
                century := century + 1
                RTCEngine.setYear((century*100)+yrs)
    
    ' update UTC offset in GPS
    UTCTemp := !ina[HighUTCPin..LowUTCPin] & %0001_1111
    UTCTemp -= 12
    if UTCTemp > 14
      UTCTemp := 14
    if not(UTCOffset == UTCTemp)
      hrs := (hrs-UTCOffset + (24 + (UTCTemp))) // 24
      UTCOffset := UTCTemp
      gps.stop
      gps.startx(GPS_RX, UTCOffset, 9600, 1250)
      RTCEngine.setHours(hrs)
    
    ' update DST
    if not ina[DSTPin]
      DST := isDST
      if DST
        ' Calendar will be off by a day from 11pm to midnight
        hrs := (hrs+1)//24
    
        ' Write hours to display buffer
    case hrs  ' Display AM/PM
      0     : ' 12am
              DspBuff[5] := numberToBCD(12) >> nibble
              DspBuff[4] := numberToBCD(12) & lsnibble
      1..9  : '  1am to 9am
              DspBuff[5] := lsnibble
              DspBuff[4] := numberToBCD(hrs) & lsnibble
      10..11: ' 10am to 11am
              DspBuff[5] := numberToBCD(hrs) >> nibble
              DspBuff[4] := numberToBCD(hrs) & lsnibble
      12    : ' 12pm
              DspBuff[5] := (numberToBCD(12) >> nibble) | dispdp
              DspBuff[4] := numberToBCD(12) & lsnibble
      13..21: '  1pm to  9pm
              DspBuff[5] := lonedp
              DspBuff[4] := numberToBCD(hrs - 12) & lsnibble
      22..23: ' 10pm to 11pm
              DspBuff[5] := (numberToBCD(hrs - 12) >> nibble) | dispdp
              DspBuff[4] := numberToBCD(hrs - 12) & lsnibble
    
    ' Write minutes to display buffer
    DspBuff[3] := (numberToBCD(mns) >> nibble) | dispdp
    DspBuff[2] := numberToBCD(mns) & lsnibble
    
    ' Write seconds to display buffer, blink decimal point on GPS fix
    DspBuff[1] := (numberToBCD(secs) >> nibble) | dispdp
    if gpsfix > 0
      DspBuff[0] := (numberToBCD(secs) & lsnibble) | dispdp
    else
      DspBuff[0] := numberToBCD(secs) & lsnibble
    
    ' Anti poisoning (3am everyday)
    if hrs == 3
      if mns == 0
        flags |= flgDirect  ' Enable direct drive
          repeat i from 0 to 5
            if secs > 29
              DspBuff[i] := numberToBCD(secs // 10)
            else
              DspBuff[i] := numberToBCD(secs // 10) | dispdp
      else
        flags &= !flgDirect ' Disable direct drive
    
    {{'Display debug
    repeat i from 0 to 5
      DspBuff[i] := (secs // 10) | dispdp
    '}}
    
    ' Sleep until last display refresh before checking sync
    repeat until (phsa => RTCfreq*(refreshRate-5)/refreshRate or ina[GPS_PPS])
      ' Sleep in between edges or as soon as PPS goes high
      waitpne(|< RTC_32k, (|< RTC_32k) & (|< GPS_PPS), 0)
      waitpne(|< 0,       (|< RTC_32k) & (|< GPS_PPS), 0)
    
    ' wait until we lock the resource
    ' By locking the resource here we guarantee
    ' that the seconds digit is updated just
    ' after the sync point
    repeat until not lockset(SemID)
    updatetime := cnt
    
    ' main loop second sync point
    if gpsfix > 0
      ' Synchronize the main loop to the GPS
      repeat until ina[GPS_PPS]   ' Sync up to GPS PPS
        ' Sleep in between edges or as soon as PPS goes high
        waitpne(|< RTC_32k, (|< RTC_32k) & (|< GPS_PPS), 0)
        waitpne(|< 0,       (|< RTC_32k) & (|< GPS_PPS), 0)
        ' If GPS is lost the PPS will never come
        ' Must wait more than one RTC second in case RTC is fast
        if phsa => RTCmax
          ' don't display gps lock indicator if PPS isn't showing up
          DspBuff[0] := DspBuff[0] & !dispdp
          quit
      if phsa < RTCmax
        phsa := 0
      else
        ' account for the missing part of a second
        phsa := RTCmax - RTCfreq
    else
      ' Synchronize the main loop to the RTC SQW phsa counter
      repeat until phsa => RTCfreq ' Wait for square wave counter
        ' Sleep in between edges
        waitpne(|< RTC_32k, |< RTC_32k, 0)
        waitpne(|< 0,       |< RTC_32k, 0)
      phsa := 0
    
    bytemove(@DspBuff1, @DspBuff, 6)
    lockclr(SemID)
    updatetime := cnt - updatetime
    
    ' Setting the seconds resets the time
    ' set seconds after updating display so
    ' it's close to start of second but does not
    ' delay display (1 ms to set seconds)
    ' loop after  point to display update takes < 122 us
    if gpsfix > 0
      RTCEngine.setSeconds(secs)
    
    if flags & flgPrint
      ' Print out time to the console
      clearterm
      printtime
      term.tx(LF)
      term.tx(CLREOL)
      printdate
    
    repeat until phsa => RTCfreq/4  ' Sleep for 250 ms before pulling the time
      ' Sleep in between edges
      waitpne(|< RTC_32k, |< RTC_32k, 0)
      waitpne(|< 0,       |< RTC_32k, 0)
    

PRI numberToBCD(number) ' 4 Stack Longs 

  return ((((number / 10) << nibble) + (number // 10)) & $ff)

PRI setdate
  
  term.Str(String("Date Day of Week(Sun=1); "))
  term.tx(LF)
  dayofwk := term.GetDec
  
  term.Str(String("Date Day; "))
  term.tx(LF)
  days := term.GetDec
  
  term.Str(String("Date Mon; "))
  term.tx(LF)
  mons := term.GetDec
  
  term.Str(String("Date Year; "))
  term.tx(LF)
  yrs := term.GetDec
  
  RTCEngine.setYear(yrs)
  RTCEngine.setMonth(mons)
  RTCEngine.setDay(days)
  RTCEngine.setDate(dayofwk)
  printdate
  term.tx(LF)

PRI settime
  
  term.Str(String("Time Hour; "))
  term.tx(LF)
  hrs := term.GetDec
  
  term.Str(String("Time Min; "))
  term.tx(LF)
  mns := term.GetDec
  
  term.Str(String("Time Sec; "))
  term.tx(LF)
  secs := term.GetDec
  
  RTCEngine.setHours(hrs)
  RTCEngine.setMinutes(mns)
  RTCEngine.setSeconds(secs)
  printtime
  term.tx(LF)

PRI uppercase(c) : chr
  if lookdown(c: "a".."z")
    c -= $20
  chr := c

PRI clearterm
  ' reset the console display
  term.tx(CLS)
  moveto(0,0)

PRI moveto(x, y)
 ' Position PST cursor at x/y
  term.tx(GOTOXY)
  term.tx(x)
  term.tx(y)

PRI printtime
  ' Print Time
  term.str(string("TIME: "))
  term.dec(RTCEngine.getHours)
  term.tx(":")
  term.dec(RTCEngine.getMinutes)
  term.tx(":")
  term.dec(RTCEngine.getSeconds)
  term.tx(CLREOL)
  
  ' Print GPS Fix Status
  term.tx(LF)
  term.str(String("FIX:  "))
  term.str(gps.s_gpsfix)
  term.tx(CLREOL)
  
  ' Print GPS Time
  term.tx(LF)
  term.str(String("GPS:  "))
  term.dec((ASCII.decimalToInteger(gps.s_local_time)/10000)//100)
  term.tx(":")
  term.dec((ASCII.decimalToInteger(gps.s_local_time)/100)//100)
  term.tx(":")
  term.dec(ASCII.decimalToInteger(gps.s_local_time)//100)
  term.tx(CLREOL)
  
  ' If GPS is valid, print the location.
  if gps.n_gpsfix > 0
    term.tx(LF)
    term.str(String(" SAT: "))
    term.str(gps.s_satellites)
    term.tx(CLREOL)
    term.tx(LF)
    term.str(String(" LAT: 0"))
    term.str(gps.s_latitude)
    term.tx(CLREOL)
    term.tx(LF)
    term.str(String(" LON: "))
    term.str(gps.s_longitude)
    term.tx(CLREOL)
    term.tx(LF)
    term.str(String(" ALT: "))
    term.str(gps.s_altm)
    term.tx(CLREOL)
  
  ' Print the UTC Offset
  term.tx(LF)
  term.str(String("UTCO: "))
  term.str(ASCII.integerToDecimal(UTCOffset,1))
  term.tx(CLREOL)

PRI printdate
  ' Print the Date
  term.tx(LF)
  term.str(string("DATE: "))
  term.dec(mons)
  term.tx("/")
  term.dec(days)
  term.tx("/")
  term.dec((century*100)+yrs)
  term.tx(CLREOL)
  
  ' Print the Day of the Week
  term.tx(LF)
  term.str(string("DOW:  "))
  term.str(dowStr(dayofwk))
  term.tx(CLREOL)
  
  ' Print DST
  term.tx(LF)
  term.str(string("DST:  "))
  if DST
    term.str(string("True"))
  else
    term.str(String("False"))
  term.tx(CLREOL)
  
  ' counter debug
  term.tx(LF)
  term.str(string("DEL:  "))
  term.str(fstring.FloatToString(fmath.FDiv(fmath.FMul(fmath.FFloat(updatetime),fmath.FFloat(1_000_000)),fmath.FFloat(clkfreq))))
  term.str(string(" us"))
  term.tx(CLREOL)

PRI dowStr(val)
  ' Convert Day of the Week integer to string
  case val
    1 : return String("Sunday")
    2 : return String("Monday")
    3 : return String("Tuesday")
    4 : return String("Wednesday")
    5 : return String("Thursday")
    6 : return String("Friday")
    7 : return String("Saturday")

PRI ShowDig | digPos, digit, digwrd, segwrd, Time, scanRate, tubeTC
' ShowDig runs in its own cog and continually updates the display
' Digit 0-9 shows decimal number
' Digit bit $80 shows left hand decimal point
' Digit value 10-15 is Blank
  
  ' How long to wait for the driver to turn off (20 us)
  tubeTC := clkfreq / 50_000
  
  dira[Seg0Pin..Seg9Pin]~~          ' Set segment pins to outputs
  dira[LowCharPin..HighCharPin]~~   ' Set numeric pins to outputs
  dira[DPPin]~~                     ' Set decimal point pin to output
  
  repeat
    if flags & isEnabled
      if flags & flgDirect
        scanRate := 6
      else
        scanRate := refreshRate
      
      repeat until not lockset(SemID)
      
      Time := cnt
      repeat digPos from 0 to 5                 ' Get next digit position
        digit  := byte[@DspBuff1][digPos]       ' Get char and validate
        segwrd := word[@NumTab][digit&$f] & $ffff
        digwrd := word[@DigSel][digPos]
        
        if (digit&$80 or segwrd)                ' something to show?
          outa[Seg9Pin..Seg0Pin] := segwrd      ' Enable the next character
          outa[DPPin] := (digit&$80) >> 7
          outa[LowCharPin..HighCharPin] := digwrd
        waitcnt(Time+=(clkfreq/scanRate)-tubeTC)' Wait before moving to next digit
        outa[LowCharPin..HighCharPin]~          ' Turn off all digits
        waitcnt(Time+= tubeTC)                  ' Wait for drivers to turn off
      lockclr(SemID)
    else
      outa[HighCharPin..LowCharPin]~~           ' Disable all characters if not in direct drive
      waitcnt (clkfreq / 10 + cnt)              ' Wait 1/10 second before checking again


PRI isDST | previousSunday
  ' Check if after 2am on the 2nd Sunday of March
  ' and before 2am on the 1st Sunday in November
  ' January, february, and december are out.
  if (mons < 3  or mons > 11)
    return false
  ' April to October are in
  if (mons > 3 and mons < 11)
    return true
  previousSunday := days - (dayofwk-1)
  
  ' In march, we are DST if our previous sunday was on or after the 8th.
  if mons == 3
    if previousSunday >= 8
      if (days > 7 and days < 15) and (dayofwk == 1)
        if hrs > 1
          return true
        else
          return false
      else
        return true
    else
      return false
  ' In november we must be before the first sunday to be dst.
  ' That means the previous sunday must be before the 1st.
  if previousSunday <= 0
    return true
  else
    if days < 8 and hrs < 2
      return true
    else
      return false





DAT
' Common anode 10-segment displays are activated by bringing the anode to + voltage
DigSel      word    %00000001  'Rightmost character
            word    %00000010  
            word    %00000100  
            word    %00001000  
            word    %00010000  
            word    %00100000  
NumTab
Dig_0       word    %0000000000000001   'K0
Dig_1       word    %0000000000000010   'K1
Dig_2       word    %0000000000000100   'K2
Dig_3       word    %0000000000001000   'K3
Dig_4       word    %0000000000010000   'K4
Dig_5       word    %0000000000100000   'K5
Dig_6       word    %0000000001000000   'K6
Dig_7       word    %0000000010000000   'K7
Dig_8       word    %0000000100000000   'K8
Dig_9       word    %0000001000000000   'K9
Dig_BL      word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank

Dig_P       word    %0000010000000000   'KP