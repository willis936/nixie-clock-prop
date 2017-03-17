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


OBJ
  RTCEngine     : "RTCEngine"
  gps           : "gps_basic"
  term          : "FullDuplexSerialPlus"
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
  byte hrs, mns, secs
  byte days, mons, yrs, dayofwk
  byte SemID
  byte DST, century, gpsfix
  
  byte   DspBuff[6]             ' 6 byte display buffer
  byte   DspBuff1[6]            ' 6 byte display buffer1
  
CON
  isEnabled  = %0001            ' Display ENABLE flag
  flgPrint   = %0010            ' Print to terminal flag
  flgDirect  = %0100            ' Direct Drive mode flag
  flgDST     = %1000            ' DST checking flag
  
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
  
  RTC_SQW       = 25
  RTC_i2cSCL    = 28
  RTC_i2cSDA    = 29

con

   #1, HOME, GOTOXY, #8, BKSP, TAB, LF, CLREOL, CLRDN, CR       ' Terminal formmatting control
  #14, GOTOX, GOTOY, CLS

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
  SemID       := locknew
  
  dira[HVPS_ENB]~~        ' Enable high voltage
  outa[HVPS_ENB]~~
  
  dira[GPS_PPS]~          ' Set PPS pin to input
  dira[RTC_SQW]~          ' Set SQW pin to input
  
  ctra[30..26] := %01010  ' Set up counter for counting positive edges
  ctra[5..0]   := RTC_SQW ' Monitor the SQW pin
  frqa         := 1       ' Add 1 to phsa register for every clock tick
  phsa         := 0       ' Clear counter register
  
  dira[HighUTCPin..LowUTCPin]~  ' Set UTC Offset dipswitch pins to input
  dira[DSTPin]~                 ' Set DST enable pin to input
  
  ' Initialize square wave output from RTC to 8192 Hz
  RTCEngine.setControl(%0001_1000)
  
  ' GPS serial port setup
  gps.startx(GPS_RX, UTCOffset, 9600, 1250)
  
  term.start(31, 30, 0, 115200)
  clearterm
  term.Str(String("Paul's Nixie Clock"))
  term.tx(CLREOL)
  term.tx(LF)
  term.tx(CLREOL)
  
  bytefill(@DspBuff1, $0, 6)
  runningCogID := cognew(ShowDig, @stack) + 1   ' start the rgb cog
  
  flags := isEnabled
  
  secs := RTCEngine.getSeconds
  if secs == 80  ' Converted from binary to bcd
    ' The clock has not been initialized so let's set it
    ' This will demonstrate hour & day roleover.
    setdate
    settime
  
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
    if gpsfix > 0' and (hrs > 11 and secs > 10)
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
      'hrs  := 10
      'mns  := 59
      'secs := 50
      ' Get the time, assume you just read the data for the next second
      ' Assuming data is from one second ago, take care of time rollover
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
        elseif i == 1
          
          ' Only update the date when not rolling over a day
          RTCEngine.setYear((century*100)+yrs)
          RTCEngine.setMonth(mons)
          RTCEngine.setDay(days)
          RTCEngine.setDate(dayofwk)
      
      ' update the RTC when there is a GPS fix
      RTCEngine.setHours(hrs)
      RTCEngine.setMinutes(mns)
      RTCEngine.setSeconds(secs)
      
	    ' Synchronize the main loop to the GPS
      repeat until ina[GPS_PPS]   ' Sync up to GPS PPS
        ' Sleep in between edges or as soon as PPS goes high
        waitpne(|< RTC_SQW, (|< RTC_SQW) & (|< GPS_PPS), 0)
        waitpne(|< 0,       (|< RTC_SQW) & (|< GPS_PPS), 0)
        ' If GPS is lost the PPS will never come
        ' Must wait more than one RTC second in case RTC is fast
        if phsa > 9215
          quit
      ' account for the missing 1/8 of a second
      if phsa > 9215
        phsa := 1024
      else
        phsa := 0
    else
      ' get the date
      yrs     := RTCEngine.getYear
      mons    := RTCEngine.getMonth
      days    := RTCEngine.getDay
      dayofwk := RTCEngine.getDate
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
      repeat until phsa > 8191 ' Wait for square wave counter to reach 8192
        ' Sleep in between edges
        waitpne(|< RTC_SQW, |< RTC_SQW, 0)
        waitpne(|< 0,       |< RTC_SQW, 0)
      phsa := 0
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
      DspBuff[i] := (secs // 10) | dispdp}}
    
    'wait until we lock the resource
    repeat until not lockset(SemID)
    bytemove(@DspBuff1, @DspBuff, 6)
    lockclr(SemID)
    
    if flags & flgPrint
      ' Print out time to the console
      clearterm
      printtime
      term.tx(LF)
      term.tx(CLREOL)
      printdate

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
  fmt2dig(RTCEngine.getHours)
  term.tx(":")
  fmt2dig(RTCEngine.getMinutes)
  term.tx(":")
  fmt2dig(RTCEngine.getSeconds)
  term.tx(CLREOL)
  
  ' Print GPS Fix Status
  term.tx(LF)
  term.str(String("FIX:  "))
  term.str(gps.s_gpsfix)
  term.tx(CLREOL)
  
  ' Print GPS Time
  term.tx(LF)
  term.str(String("GPS:  "))
  fmt2dig((ASCII.decimalToInteger(gps.s_local_time)/10000)//100)
  term.tx(":")
  fmt2dig((ASCII.decimalToInteger(gps.s_local_time)/100)//100)
  term.tx(":")
  fmt2dig(ASCII.decimalToInteger(gps.s_local_time)//100)
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
  fmt2dig(mons)
  term.tx("/")
  fmt2dig(days)
  term.tx("/")
  fmt2dig((century*100)+yrs)
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
    term.str(String("True"))
  else
    term.str(String("False"))
  term.tx(CLREOL)
  
  ' counter debug
  term.tx(LF)
  term.str(string("PHSA: "))
  fmt2dig(phsa)
  term.tx(CLREOL)

  
PRI fmt2dig(val)
  ' Print integer
  if val < 10
    term.tx("0")
  term.dec(val)

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

PRI ShowDig | digPos, digit , digwrd, segwrd, refreshRate
' ShowDig runs in its own cog and continually updates the display
' Digit 0-9 shows decimal number
' Digit bit $80 shows left hand decimal point
' Digit value 10-15 is Blank

  dira[Seg0Pin..Seg9Pin]~~          ' Set segment pins to outputs
  dira[LowCharPin..HighCharPin]~~   ' Set numeric pins to outputs
  dira[DPPin]~~                     ' Set decimal point pin to output
  repeat until not lockset(SemID)
  
  repeat
    if flags & isEnabled
      if flags & flgDirect
        refreshRate := 6
      else
        ' refresh rate controls max accuracy.
        '  720: (120 Hz   15% duty cycle, 8.3 ms accuracy)
        ' 1440: (240 Hz 11.2% duty cycle, 4.1 ms accuracy)
        ' 2880: (480 Hz  6.3% duty cycle, 2.1 ms accuracy)
        refreshRate := 2880
      repeat digPos from 0 to 5                  ' Get next digit position
        digit  := byte[@DspBuff1][digPos]        ' Get char and validate
        segwrd := word[@NumTab][digit&$f] & $ffff
        digwrd := word[@DigSel][digPos]
        
        if (digit&$80 or segwrd)                 ' something to show?
          outa[Seg9Pin..Seg0Pin] := segwrd       ' Enable the next character
          outa[DPPin] := (digit&$80) >> 7
          waitcnt (clkfreq / 25_000 + cnt)       ' Wait 20 usec for drivers to turn off
          outa[LowCharPin..HighCharPin] := digwrd
        else
          waitcnt (clkfreq / 25_000 + cnt)       ' Wait 20 usec for drivers to turn off
        
        if digPos == 5
          lockclr(SemID)
          waitcnt (clkfreq / refreshRate + cnt)  ' Wait 2000 usec (500 Hz, 83.3 Hz per digit)
          repeat until not lockset(SemID)
        else
          waitcnt (clkfreq / refreshRate + cnt)  ' Wait 2000 usec
        outa[LowCharPin..HighCharPin]~
        
    else
      outa[HighCharPin..LowCharPin]~~              ' Disable all characters if not in direct drive
      waitcnt (clkfreq / 10 + cnt)                 ' Wait 1/10 second before checking again


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