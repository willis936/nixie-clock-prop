{{ Nixie_Clock_Main.spin}}

CON
  _clkmode = xtal1 + pll16x 
  _xinfreq = 5_000_000

 
OBJ
  i2cObject     : "basic_i2c_driver"
  SN            : "Simple_Numbers"
  ds1307object  : "DS1307Obj"
  debug         : "SerialMirror"        'Same as fullDuplexSerial, but can also call from subroutines

  
VAR
  byte hour, minute, second, day, month, year, dow
  byte cmd, out
  byte data[12]
  long LowCharPin, HighCharPin                          'The pins for specifying chars.
  long DPPin                          'The pins for specifying chars.
  long Seg0Pin, Seg9Pin                                'The pins for the segments.
  long flags
  long runningCogID
  long stack[50]   
  byte hrs, mns, secs
  byte days, mons, yrs, dayofwk

  
  byte   DspBuff[6]            '6 byte display buffer  
CON
  isEnabled  = %0001                                    'Display ENABLE flag

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
' setup i2cobject
   i2cObject.Initialize(i2cSCL)

  Debug.start(31, 30, 0, 57600)
  Debug.Str(String("Paul's Nixie Clock Initializing...",13,10))

  bytefill(@DspBuff, $f, 6)
  runningCogID := cognew(ShowDig, @stack) + 1                 ' start the rgb cog
'  waitcnt(clkfreq*1+cnt)   

  flags := isEnabled 
 
  secs := ds1307object.gettime(i2cSCL,ds1307addr)
  if secs == 80
      ' the clock has not been initialised so lets set it
      ' this will demonstrate hour & day roleover.

    Debug.Str(String("Date Day of Week(Sun=1); "))
    dayofwk := Debug.GetNumber   

    Debug.Str(String("Date Day; "))
    days := Debug.GetNumber   
     
    Debug.Str(String("Date Mon; "))
    mons := Debug.GetNumber   
     
    Debug.Str(String("Date Year; "))
    yrs := Debug.GetNumber   
     
    Debug.Str(String("Time Hour; "))
    hrs := Debug.GetNumber   
     
    Debug.Str(String("Time Min; "))
    mns := Debug.GetNumber   
     
    Debug.Str(String("Time Sec; "))
    secs := Debug.GetNumber   
     
    ds1307object.settime(i2cSCL,ds1307addr,hrs,mns,secs)
    ds1307object.setdate(i2cSCL,ds1307addr,dayofwk,days,mons,yrs)
     
  repeat
    ' get and display the TIME
    ds1307object.gettime(i2cSCL,ds1307addr)
    hrs := ds1307object.getHours
    DspBuff[5] := numberToBCD(hrs) >> 4
    DspBuff[4] := numberToBCD(hrs) & $f
    
    mns := ds1307object.getMinutes
    DspBuff[3] := numberToBCD(mns) >> 4
    DspBuff[2] := numberToBCD(mns) & $f

    secs := ds1307object.getSeconds
    DspBuff[1] := numberToBCD(secs) >> 4
    DspBuff[0] := numberToBCD(secs) & $f
     
     ' get and display the DATE
    ds1307object.getdate(i2cSCL,ds1307addr)
    days := ds1307object.getDays
    mons := ds1307object.getMonths
    yrs := ds1307object.getYears


    ' get and display the TIME
    debug.str(string("TIME: "))
    debug.dec (hrs)
    debug.tx(":")
    debug.dec (mns)
    debug.tx(":")                                       
    debug.dec (secs)
     
    ' get and display the DATE
    debug.str(string("  DATE: "))
    debug.dec (days)
    debug.tx("/")
    debug.dec (mons)
    debug.tx("/")                                       
    debug.dec (yrs)
    debug.CrLf
     

    ' wait a second
    waitcnt(clkfreq+cnt)
     

PRI numberToBCD(number) ' 4 Stack Longs 

  return (((number / 10) << 4) + (number // 10))
                                         


PRI ShowDig | digPos, digit
' ShowDig runs in its own cog and continually updates the display
' Digit 0-9 shows decimal number
' Digit bit $80 shows left hand decimal point
' Digit value 10-15 is Blank

  dira[Seg0Pin..Seg9Pin]~~                              'Set segment pins to outputs
  dira[LowCharPin..HighCharPin]~~                         'Set numeric pins to outputs
  dira[DPPin]~~
  
  repeat
    if flags & isEnabled
      repeat digPos from 0 to HighCharPin - LowCharPin  'Get next digit position
        digit := byte[@DspBuff][digPos]                   'Get char and validate
        outa[Seg9Pin..Seg0Pin]~                         'Clear the segments to avoid flicker                                                         
        waitcnt (clkfreq / 100_000 + cnt)               'Wait 10 usec for drivers to turn off

        outa[LowCharPin..HighCharPin] := word[@DigSel][digPos]
        outa[Seg9Pin..Seg0Pin] := word[@NumTab][digit&$f]  'Enable the next character
        if (digit&$80)
          outa[DPPin]~~
        else
          outa[DPPin]~
        waitcnt (clkfreq / 500 + cnt)                 'Wait 1000 usec

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