{{ Nixie_Clock_Main.spin}}

CON
  _clkmode = xtal1 + pll16x 
  _xinfreq = 5_000_000

 
OBJ
  i2cObject     : "basic_i2c_driver"
  ds1307object  : "DS1307Obj"
  debug         : "FullDuplexSerialPlus"

  
VAR
  byte hour, minute, second, day, month, year, dow
  byte cmd, out
  byte data[12]
  long LowCharPin, HighCharPin        'The pins for specifying chars.
  long DPPin                          'The pins for specifying chars.
  long Seg0Pin, Seg9Pin               'The pins for the segments.
  long flags
  long runningCogID
  long stack[50]
  long nxtTime   
  byte hrs, mns, secs
  byte days, mons, yrs, dayofwk
  byte SemID, lastsec
  
  byte   DspBuff[6]            '6 byte display buffer  
  byte   DspBuff1[6]           '6 byte display buffer1
    
CON
  isEnabled  = %0001                                    'Display ENABLE flag
  flgPrint   = %0010
  
  DS1307Addr    = %1101_0000
             

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

  HVPS_ENB      = 17
  TCO           = 23
  PB1           = 24
  PB2           = 25

  i2cSCL        = 28
'  i2cSDA        = 29 
  
PUB main| i,c

  dira[HVPS_ENB]~~
  outa[HVPS_ENB]~~        

  LowCharPin := 10
  HighCharPin :=15                          'The pins for specifying chars.
  Seg0Pin := 0
  Seg9Pin := 9                                'The pins for the segments.
  DPPin := 16
  SemID := locknew
' setup i2cobject
  i2cObject.Initialize(i2cSCL)

  Debug.start(31, 30, 0, 115200)
  Debug.Str(String("Paul's Nixie Clock V006"))
  crlf

  bytefill(@DspBuff1, $0, 6)
  runningCogID := cognew(ShowDig, @stack) + 1                 ' start the rgb cog
  waitcnt(clkfreq*1+cnt)   

  flags := isEnabled 
 
  secs := ds1307object.gettime(i2cSCL,ds1307addr)
  if secs == 80  ' converted from binary to bcd
      ' the clock has not been initialised so lets set it
      ' this will demonstrate hour & day roleover.
    setdate
    settime

  lastsec := -1
  nxtTime := cnt
  Debug.Str(String("D = setdate, S = settime, S = show time",13,10))    
  repeat
    c := uppercase(Debug.rxcheck)
    if c == "D"
      setdate
    if c == "T"
      settime
    if c == "S"
      flags ^= flgPrint

      
      
        ' wait a 0.1 second
    waitcnt(nxtTime += clkfreq/10) 'Wait for 100 ms
    ' get and display the TIME
    ds1307object.gettime(i2cSCL,ds1307addr)
    secs := ds1307object.gettime(i2cSCL,ds1307addr)
    if secs <> lastsec
       
      hrs := ds1307object.getHours
      if hrs < 12
        if hrs > 9
          DspBuff[5] := numberToBCD(hrs) >> 4
          DspBuff[4] := numberToBCD(hrs) & $f
        else
          if hrs => 1
            DspBuff[5] := $f
            DspBuff[4] := numberToBCD(hrs) & $f
          else
            DspBuff[5] := numberToBCD(hrs + 12) >> 4
            DspBuff[4] := numberToBCD(hrs + 12) & $f
      else
        if hrs > 21
          DspBuff[5] := numberToBCD(hrs - 12) >> 4 | $80
          DspBuff[4] := numberToBCD(hrs - 12) & $f
        else
          if hrs < 13
            DspBuff[5] := numberToBCD(hrs) >> 4 | $80
            DspBuff[4] := numberToBCD(hrs) & $f
          else
            DspBuff[5] := $f
            DspBuff[4] := numberToBCD(hrs - 12) & $f    
       
      mns := ds1307object.getMinutes
      DspBuff[3] := numberToBCD(mns) >> 4 | $80
      DspBuff[2] := numberToBCD(mns) & $f
       
      ' secs := ds1307object.getSeconds
      DspBuff[1] := numberToBCD(secs) >> 4 | $80
      DspBuff[0] := numberToBCD(secs) & $f
       
       ' get and display the DATE
      ds1307object.getdate(i2cSCL,ds1307addr)
      days := ds1307object.getDays
      mons := ds1307object.getMonths
      yrs := ds1307object.getYears
       
       'wait until we lock the resource
      repeat until not lockset(SemID)
      bytemove(@DspBuff1, @DspBuff, 6)
      lockclr(SemID)
       
      if flags & flgPrint   
        ' get and display the TIME
        printtime
        Debug.Str(String("  "))
        printdate
        crlf
      lastsec := secs 
       

       
     

PRI numberToBCD(number) ' 4 Stack Longs 

  return ( ( ( (number / 10) << 4) + (number // 10) )  & $ff )
                                         
    
PRI setdate
   
  Debug.Str(String("Date Day of Week(Sun=1); "))
  dayofwk := Debug.GetDec   
   
  Debug.Str(String("Date Day; "))
  days := Debug.GetDec   
   
  Debug.Str(String("Date Mon; "))
  mons := Debug.GetDec   
   
  Debug.Str(String("Date Year; "))
  yrs := Debug.GetDec   
  ds1307object.setdate(i2cSCL,ds1307addr,dayofwk,days,mons,yrs)
  printdate
  crlf
   
PRI settime
     
  Debug.Str(String("Time Hour; "))
  hrs := Debug.GetDec   
   
  Debug.Str(String("Time Min; "))
  mns := Debug.GetDec   
   
  Debug.Str(String("Time Sec; "))
  secs := Debug.GetDec   
   
  ds1307object.settime(i2cSCL,ds1307addr,hrs,mns,secs)
  printtime
  crlf

PUB uppercase(c) : chr
  if lookdown(c: "a".."z")
    c -= $20
  chr := c
'  return
   
PRI crlf
  debug.tx(13)
      
PRI printtime        
  debug.str(string("TIME: "))
  fmt2dig (hrs)
  debug.tx(":")
  fmt2dig (mns)
  debug.tx(":")                                       
  fmt2dig (secs)
   
PRI printdate        
  ' display the DATE
  debug.str(string("DATE: "))
  fmt2dig (mons)
  debug.tx("/")
  fmt2dig (days)
  debug.tx("/")                                       
  fmt2dig (yrs)
   
         
PRI fmt2dig(val)
  if val < 10
    debug.tx("0")
  debug.dec(val)

  
PRI ShowDig | digPos, digit , digwrd, segwrd
' ShowDig runs in its own cog and continually updates the display
' Digit 0-9 shows decimal number
' Digit bit $80 shows left hand decimal point
' Digit value 10-15 is Blank

  dira[Seg0Pin..Seg9Pin]~~                              'Set segment pins to outputs
  dira[LowCharPin..HighCharPin]~~                         'Set numeric pins to outputs
  dira[DPPin]~~
  repeat until not lockset(SemID)
  
  repeat
    if flags & isEnabled
      repeat digPos from 0 to 5  'Get next digit position
        digit :=  byte[@DspBuff1][digPos]   'Get char and validate
        segwrd := word[@NumTab][digit&$f] & $ffff
        digwrd := word[@DigSel][digPos]
        
        if (digit&$80 or segwrd )         ' something to show?
          outa[Seg9Pin..Seg0Pin] := segwrd  'Enable the next character
          outa[DPPin] := (digit&$80) >> 7
          waitcnt (clkfreq / 25_000 + cnt)               'Wait 20 usec for drivers to turn off
          outa[LowCharPin..HighCharPin] := digwrd
        else
          waitcnt (clkfreq / 25_000 + cnt)               'Wait 20 usec for drivers to turn off

        if digPos == 5
          lockclr(SemID)
          waitcnt (clkfreq / 500 + cnt)                 'Wait 1000 usec
          repeat until not lockset(SemID)
        else
          waitcnt (clkfreq / 500 + cnt)                 'Wait 1000 usec
        outa[LowCharPin..HighCharPin]~
        
    else
      outa[HighCharPin..LowCharPin]~~                   'Disable all characters
      waitcnt (clkfreq / 10 + cnt)                      'Wait 1/10 second before checking again
     







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