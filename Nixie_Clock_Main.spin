{{ Nixie_Clock_Main.spin}}

CON
  _clkmode = xtal1 + pll16x 
  _xinfreq = 5_000_000

 
OBJ
  SN    : "Simple_Numbers"
  rtc   : "DS1302_full"
  debug : "SerialMirror"        'Same as fullDuplexSerial, but can also call from subroutines

  
VAR
  byte hour, minute, second, day, month, year, dow
  byte cmd, out
  byte data[12]
  long LowNumPin, HighNumPin                          'The pins for specifying chars.
  long Dig0Pin, Dig5Pin                                'The pins for the segments.
  long flags
  long runningCogID
  
CON
  isEnabled  = %0001                                    'Display ENABLE flag


  
PUB main|i 
  waitcnt(clkfreq * 5 + cnt)                      'Start FullDuplexSerial
  Debug.start(31, 30, 0, 57600)
  Debug.Str(String("MSG,Initializing...",13))
 
  '==================================================================================
  'call this function each time the propeller starts
  rtc.init( 4, 5, 6 )                             'ports Clock, io, chip enable

  '==================================================================================
  'call this function only after DS1302 power on
  rtc.config                                      'Set configuration register

  '==================================================================================
  'set time
  rtc.setDatetime( 09, 22, 09, 3, 20, 20, 00 )    'month, day, year, day of week, hour, minute, second
                                                        
  '==================================================================================
  'change the tricle charger setup from that currently defined in the config function
  'Trickle charger setup                       tc_enable     diodeSel   resistSel
  '                                                |            |          |
  rtc.write(rtc.command(rtc#clock,rtc#tc,rtc#w),(%1010 << 4) + (1 << 2)+ ( 2 ))
  out:=rtc.read(rtc.command(rtc#clock,rtc#tc,rtc#r))
  Debug.Str(string("Trickle charge register contents = "))
  Debug.bin(out,8)
  Debug.Str(String(13,13))

  '==================================================================================
  'write data values to ram registers
  repeat i from 0 to 30
    cmd:=rtc.command(rtc#ram,i,rtc#w)
    Debug.Str(string("Writing RAM address "))
    Debug.Dec(i)
    Debug.Str(string(" cmd byte = "))
    Debug.Bin(cmd,8)
    Debug.Str(String(13))
    rtc.write(cmd,i)
  Debug.Str(String(13,13))

  '==================================================================================
  'read data values from ram registers
  repeat i from 0 to 30
    cmd:=rtc.command(rtc#ram,i,rtc#r)
    Debug.Str(string("Reading RAM address "))
    Debug.Dec(i)
    Debug.Str(string(" = "))
    out:=rtc.read(cmd)
    Debug.Dec(out)
    Debug.Str(String(13))   
  Debug.Str(String(13,13))

  '==================================================================================
  'write data to registers 0-11 in burst mode
  Debug.Str(string("Writing RAM data in burst mode"))
  repeat i from 0 to 30
    data[i]:=30-i
  cmd:=rtc.command(rtc#ram,rtc#burst,rtc#w)
  rtc.writeN(cmd,@data,12)
  Debug.Str(String(13,13))
                                                    
  '==================================================================================
  'read data registers 0-11 in burst mode
  Debug.Str(string("Reading RAM data in burst mode",13))
  cmd:=rtc.command(rtc#ram,rtc#burst,rtc#r)
  rtc.readN(cmd,@data,12)
  repeat i from 0 to 11
    Debug.Str(string("Data "))
    Debug.Dec(i)
    Debug.Str(string(" = "))
    Debug.Dec(data[i])
    Debug.Str(String(13))
  Debug.Str(String(13,13))

  '==================================================================================
  'read date and time, once per second
  repeat
     
    rtc.readTime( @hour, @minute, @second )     'read time from DS1302
    rtc.readDate( @day, @month, @year, @dow )   'read date from DS1302
    
    Debug.str( SN.decx(hour,2) )
    Debug.str( string(":"))
    Debug.str( SN.decx(minute,2) )
    Debug.str( string(":") )
    Debug.str( SN.decx(second,2))
    Debug.str( string(", ") )
    Debug.str( SN.decx(dow,2))
    Debug.str( string(" ") )
    Debug.str( SN.decx(month,2))
    Debug.str( string(" ") )
    Debug.str( SN.decx(day,2))
    Debug.str( string(" ") )
    Debug.str( SN.decx(year,2))
    Debug.Str(String(13))    
    waitcnt( clkfreq + cnt ) 


pub setcurve(curvenum, idx)

  case curvenum
    0     : return curve0[idx]
    1     : return curve0[idx]                                  ' assign new tables here
    2     : return curve0[idx]
    3     : return curve0[idx]
    other : return idx                                          ' default



PRI ShowDig | digPos, digit
' ShowDig runs in its own cog and continually updates the display
' Digit 0-9 shows decimal number
' Digit bit $80 shows left hand decimal point
' Digit value 10-15 is Blank

  dira[Dig5Pin..Dig0Pin]~~                              'Set segment pins to outputs
  dira[HighNumPin..LowNumPin]~~                         'Set numeric pins to outputs

  repeat
    if flags & isEnabled
      repeat digPos from 0 to HighNumPin - LowNumPin    'Get next digit position
        digit := byte[DspBuff+digPos]                   'Get char and validate
        outa[Dig5Pin..Dig0Pin]~                         'Clear the digit drivers                                                         
        waitcnt (clkfreq / 100_000 + cnt)               'Wait 10 usec for drivers to turn off

        outa[Dig5Pin..Dig0Pin] := byte[@DigSel+digPos] 'Enable the next character
         'Output the pattern
        outa[HighNumPin..LowNumPin] := word[@NumTab +(digit&$f) *2]
        if (digit&$80)
          outa[HighNumPin..LowNumPin] |= word[@Dig_P]
        waitcnt (clkfreq / 10_000 + cnt)                'This delay value can be tweaked to adjust
                                                        ' display brightness
    else
      outa[Dig0Pin..Dig5Pin]~                           'Clear the segments to avoid flicker                                                        
      outa[HighNumPin..LowNumPin]~~                     'Disable all characters
      waitcnt (clkfreq / 10 + cnt)                      'Wait 1/10 second before checking again
     
DAT
' Common cathode 10-segment displays are activated by bringing the cathode to ground
DigSel      byte    %00000001  'Rightmost character
            byte    %00000010  
            byte    %00000100  
            byte    %00001000  
            byte    %00010000  
            byte    %00100000  
NumTab
  Dig_0     word    %0000000000000001   'K0
  Dig_1     word    %0000000000000010   'K1
  Dig_2     word    %0000000000000100   'K2
  Dig_3     word    %0000000000001000   'K3
  Dig_4     word    %0000000000010000   'K4
  Dig_5     word    %0000000000100000   'K5
  Dig_6     word    %0000000001000000   'K6
  Dig_7     word    %0000000010000000   'K7
  Dig_8     word    %0000000100000000   'K8
  Dig_9     word    %0000001000000000   'K9
  Dig_BL    word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank
            word    %0000000000000000   'Blank

  Dig_P     word    %0000010000000000   'KP

  DspBuff   byte    "000000"            '6 byte display buffer


dat

curve0                  byte    000, 001, 002, 003, 004, 005, 006, 007
                        byte    008, 009, 010, 011, 012, 013, 014, 015
                        byte    016, 017, 018, 019, 020, 021, 022, 023
                        byte    024, 025, 026, 027, 028, 029, 030, 031
                        byte    032, 033, 034, 035, 036, 037, 038, 039
                        byte    040, 041, 042, 043, 044, 045, 046, 047
                        byte    048, 049, 050, 051, 052, 053, 054, 055
                        byte    056, 057, 058, 059, 060, 061, 062, 063
                        byte    064, 065, 066, 067, 068, 069, 070, 071
                        byte    072, 073, 074, 075, 076, 077, 078, 079
                        byte    080, 081, 082, 083, 084, 085, 086, 087
                        byte    088, 089, 090, 091, 092, 093, 094, 095
                        byte    096, 097, 098, 099, 100, 101, 102, 103
                        byte    104, 105, 106, 107, 108, 109, 110, 111
                        byte    112, 113, 114, 115, 116, 117, 118, 119
                        byte    120, 121, 122, 123, 124, 125, 126, 127
                        byte    128, 129, 130, 131, 132, 133, 134, 135
                        byte    136, 137, 138, 139, 140, 141, 142, 143
                        byte    144, 145, 146, 147, 148, 149, 150, 151
                        byte    152, 153, 154, 155, 156, 157, 158, 159
                        byte    160, 161, 162, 163, 164, 165, 166, 167
                        byte    168, 169, 170, 171, 172, 173, 174, 175
                        byte    176, 177, 178, 179, 180, 181, 182, 183
                        byte    184, 185, 186, 187, 188, 189, 190, 191
                        byte    192, 193, 194, 195, 196, 197, 198, 199
                        byte    200, 201, 202, 203, 204, 205, 206, 207
                        byte    208, 209, 210, 211, 212, 213, 214, 215
                        byte    216, 217, 218, 219, 220, 221, 222, 223
                        byte    224, 225, 226, 227, 228, 229, 230, 231
                        byte    232, 233, 234, 235, 236, 237, 238, 239
                        byte    240, 241, 242, 243, 244, 245, 246, 247
                        byte    248, 249, 250, 251, 252, 253, 254, 255


'assembly cog which updates the PWM cycle on APIN
'for audio PWM, fundamental freq which must be out of auditory range (period < 50µS)
              org
entry
              mov             t1,               #1        wz                    '     Configure Output pin
              shl             t1,               pina                            '          Create mask with t1               
              muxnz           dira,             t1                              '          Set pin as Output        "1"
              mov             t1,               #1        wz                    '     Configure Output pin
              shl             t1,               pinb                            '          Create mask with t1               
              muxnz           dira,             t1                              '          Set pin as Output        "1"
                                                 
              movs            ctraval,          pina                            ' move pin number to ctr source field
              movs            ctrbval,          pinb
              mov             frqb,             #1                              'set counter to increment 1 each cycle
              mov             frqa,             #1                              'set counter to increment 1 each cycle
              mov             ctra,             ctraval                         'establish counter A mode and APIN
              mov             ctrb,             ctrbval                         'establish counter B mode and APIN
:loop                    
              rdlong          valuea,           parma                           'get an up to date pulse width
              rdlong          valueb,           parmb                           'get an up to date pulse width
              waitcnt         time,             period                          'wait until next period
              neg             phsa,             valuea                          'back up phsa so that it
              neg             phsb,             valueb                          'back up phsa so that it
              jmp             #:loop                                            'loop for next cycle

ctraval       long      %00100 << 26 + 0                'NCO/PWM APIN=0
ctrbval       long      %00100 << 26 + 1                'NCO/PWM APIN=1
parma         long      1
parmb         long      1
pina          long      1
pinb          long      1
t1            long      1
period        long      $80000                    '524,288 = 152.588 Hz (6.55mS period) (_clkfreq / period)                      
time          long      1

valuea        res       1
valueb        res       1