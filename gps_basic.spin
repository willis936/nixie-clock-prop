'' =================================================================================================
''
''   File....... gps_basic.spin
''   Purpose.... Basic GPS parsing -- string and numeric forms 
''   Author..... Jon "JonnyMac" McPhalen
''               -- see below for terms of use
''   E-mail..... 
''   Started.... 
''   Updated.... 19 FEB 2011
''
'' =================================================================================================

{

   Notes: Consumes two cogs
   -- half-duplex uart for receiving characters from GPS
   -- parser for extracting select GPS strings from steam

   Resources:
   -- http://aprs.gids.nl/nmea
   -- http://home.mira.net/~gnb/gps/nmea.html

}


con

  RX1 = 31                                                      ' programming port
  TX1 = 30
  SDA = 29                                                      ' boot EEPROM
  SCL = 28


con

  BUF_SIZE  = 128                                               ' rx buffer (power of 2)
  WORK_SIZE = 80                                                ' for working buffers
  RSLT_SIZE = 20                                                ' temp result string

  HMS_SEP   = ":"                                               ' hrs-mins-secs separator
  DMY_SEP   = "/"                                               ' day-month-year separator
  

var

  long  hasgpsflag                                              ' gps detected
  long  utcoffset

  long  parsecog
  long  stack[32]                                               ' for parsing cog

  long  rxcog
  long  rxpin                                                   ' rx pin (from gps)
  long  rxtix                                                   ' ticks per bit @ 4800
  long  rxhead                                                  ' head pointer 
  long  rxtail                                                  ' tail pointer
  long  rxbufaddr                                               ' address of rx buffer
  long  rxtimeout                                               ' max wait for serial data (ms)
  
  byte  rxbuf[BUF_SIZE]                                         ' receive buffer (32 longs)

  byte  gpswork[WORK_SIZE]                                      ' working buffers
  byte  rmcwork[WORK_SIZE]
  byte  ggawork[WORK_SIZE]

  byte  gpsrslt[RSLT_SIZE]                                      ' result string
  

dat

RMC_HDR                 byte    "GPRMC,", 0
GGA_HDR                 byte    "GPGGA,", 0


pub start(rxd, utcofs)

'' Starts RX and GPS parser cogs
'' -- uses default 4800 baud, true mode comms
'' -- uses default timeout for 2-sec updates

  return startx(rxd, utcofs, 4_800, 2_500)


pub startx(rxd, utcofs, baud, timeout)

'' Starts RX and GPS parser cogs
'' -- allows user-specified baud rate (negative for inverted baud mode)
'' -- allows user-specified serial timeout (ms)

  stop

  rxpin := rxd                                                  ' assign pin
  rxtix := clkfreq / baud                                       ' assign baud

  rxbufaddr := @rxbuf[0]                                        ' locate buffer
  rxtimeout := timeout

  utcoffset := -23 #> utcofs <# 23                              ' set offset

  rxcog := cognew(@rxserial, @rxpin) + 1                        ' start rx uart cog

  if rxcog
    parsecog := cognew(parse_gps, @stack) + 1                   ' start parser cog

  return (rxcog) and (parsecog)


pub stop

'' Stops previously-loaded cogs and flushes buffers

  if rxcog                                                      ' if running
    cogstop(rxcog~ - 1)

  if parsecog
    cogstop(parsecog~ - 1)

  longfill(@rxhead, 0, 2)                                       ' flush buffers
  bytefill(@rxbuf, 0, BUF_SIZE)
  bytefill(@gpsrslt, 0, RSLT_SIZE)


pub hasgps

'' Returns true when UART actively receiving characters

  return hasgpsflag


pub s_gpsfix

'' Returns GPS fix quality as z-string

  case n_gpsfix                                                 ' from dec to string
    0 : bytemove(@gpsrslt, string("Invalid"), 8)
    1 : bytemove(@gpsrslt, string("GPS"), 4)
    2 : bytemove(@gpsrslt, string("DGPS"), 5)

  return @gpsrslt                                               ' return pointer


pub n_gpsfix

'' Returns GPS fix quality
'' -- 0 = invalid, 1 = GPS fix, 2 = DGPS fix

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear workspace

  if (strncmp(@GGA_HDR, @ggawork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @ggawork, 6)                            '  yes, get fix field

  return str2dec(@gpsrslt, 1)                                   ' return fix


pub s_satellites

'' Returns satellites in view as z-string, "0".."??"

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@GGA_HDR, @ggawork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @ggawork, 7)                            '  yes, get sats field

  return @gpsrslt                                               ' return pointer

  
pub n_satellites

'' Returns satellites in view as decimal value, 0..??

  s_satellites

  return str2dec(@gpsrslt, 2)                                   ' return satellites  

  
pub s_utc_time

'' UTC time as z-string: "HHMMSS"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 1)                            ' get time field
    gpsrslt[6] := 0                                             ' terminate (no ms) 

  return @gpsrslt                                               ' return pointer


pub fs_utc_time

'' UTC time as formatted z-string: "HH:MM:SS"
'' -- returns pointer to result string

  s_utc_time                                                    ' get time field
  if (gpsrslt > 0)                                              ' if not empty
    s_insert(HMS_SEP, 4, @gpsrslt)                              '  separate secs
    s_insert(HMS_SEP, 2, @gpsrslt)                              '  separate mins
    gpsrslt[8] := 0                                             '  terminate (no ms) 

  return @gpsrslt                                               ' return pointer
 

pub s_local_time | hr

'' Local time as z-string: "HHMMSS"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result
 
  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 1)                            ' get time field
    hr := str2dec(@gpsrslt, 2)                                  '  get utc hours
    hr := (hr + (24 + utcoffset)) // 24                         '  add utc offset
    gpsrslt[0] := (hr  / 10) + "0"                              '  convert back to string
    gpsrslt[1] := (hr // 10) + "0"
    gpsrslt[6] := 0                                             '  terminate (no ms)  

  return @gpsrslt                                               ' return pointer


pub fs_local_time

'' Local time as formated z-string: "HH:MM:SS"
'' -- returns pointer to result string

  s_local_time                                                  ' get time string
  if (gpsrslt > 0)                                              ' if not empty
    s_insert(HMS_SEP, 4, @gpsrslt)                              '  separate secs
    s_insert(HMS_SEP, 2, @gpsrslt)                              '  separate mins
    gpsrslt[8] := 0                                             '  terminate (no ms)  

  return @gpsrslt                                               ' return pointer

  
pub s_utc_hrs

'' UTC hours as z-string: "00".."23" (UTC time)
'' -- returns pointer to result string 

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 1)                            ' get time field
    gpsrslt[2] := 0                                             ' terminate
    
  return @gpsrslt                                               ' return pointer


pub n_utc_hrs

'' UTC hours as decimal value, 0..23
'' -- returns -1 if gps string is invalid 

  s_utc_hrs                                                     ' get hours
  if (gpsrslt[0] > 0)                                           ' if not empty
    return str2dec(@gpsrslt[2], 2)                              ' convert 
  else
    return -1                                                   ' error

  
pub s_local_hrs | hr

'' Local hours as z-string: "00".."23" 
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 1)                            '  yes, get time field
    hr := str2dec(@gpsrslt, 2)                                  '  get utc hours
    hr := (hr + (24 + utcoffset)) // 24                         '  add utc offset
    gpsrslt[0] := (hr  / 10) + "0"                              '  convert back to string
    gpsrslt[1] := (hr // 10) + "0"
    gpsrslt[2] := 0                                             '  terminate

  return @gpsrslt                                               ' return pointer 


pub n_local_hrs

'' Local hours as decimal value, 0..23
'' -- returns -1 if gps string is invalid

  s_local_hrs                                                   ' get hours
  if (gpsrslt[0] > 0)                                           ' if not empty
    return str2dec(@gpsrslt[2], 2)                              ' convert to dec
  else
    return -1                                                   ' error
    

pub s_mins 

'' (Current time) Minutes as z-string: "00".."59"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 1)                            '  yes, get time field
    bytemove(@gpsrslt[0], @gpsrslt[2], 2)                       '  yes, copy minutes
    gpsrslt[2] := 0                                             '  terminate

  return @gpsrslt                                               ' return pointer 


pub n_mins

'' (Current time) Minutes as decimal value, 0..59
'' -- returns -1 if gps string is invalid

  s_mins                                                        ' get minutes
  if (gpsrslt[0] > 0)                                           ' if not empty
    return str2dec(@gpsrslt[2], 2)                              ' convert seconds
  else
    return -1                                                   ' error
  

pub s_secs 

'' Seconds as z-string: "00".."59"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 1)                            '  yes, get time field
    bytemove(@gpsrslt, @gpsrslt[4], 2)                          '  yes, copy seconds

  return @gpsrslt                                               ' return pointer
  
 
pub n_secs

'' Seconds as decimal value, 0..59
'' -- returns -1 if gps string is invalid 

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    return str2dec(@rmcwork[11], 2)                             ' yes, convert seconds
  else
    return -1                                                   ' no, error


pub s_date

'' Current date as z-string: "DDMMYY"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result

  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data?
    gps_fcopy(@gpsrslt, @rmcwork, 9)                            '  yes, get date field

  return @gpsrslt                                               ' return pointer
  
  
pub fs_date

'' Current date as formatted z-string: "DD/MM/YY"
'' -- returns pointer to result string

  s_date                                                        ' get date field
  if (gpsrslt[0] > 0)                                           ' if not empty
    s_insert(DMY_SEP, 4, @gpsrslt)                              '  separate year
    s_insert(DMY_SEP, 2, @gpsrslt)                              '  separate month  

  return @gpsrslt                                               ' return pointer


pub s_day

'' Current day as z-string: "01".."31"
'' -- returns pointer to result string

  s_date                                                        ' get date field
  gpsrslt[2] := 0                                               ' terminate after day     

  return @gpsrslt                                               ' return pointer


pub n_day

'' Current day as decimal value, 1..31
'' -- returns -1 if gps string is invalid

  s_date                                                        ' get date field
  if (gpsrslt[0] > 0)                                           ' if not empty
    return str2dec(@gpsrslt[0], 2)                              ' return day                              
  else
    return -1                                                   ' error
  
  
pub s_month

'' Current month as z-string: "01".."12"
'' -- returns pointer to result string

  s_date                                                        ' get date field
  bytemove(@gpsrslt, @gpsrslt[2], 2)                            ' move month
  gpsrslt[2] := 0                                               ' terminate 

  return @gpsrslt                                               ' return pointer


pub n_month 

'' Current month as decimal value, 1..12
'' -- returns -1 if gps string is invalid  

  s_month                                                       ' get month string
  if (gpsrslt[0] > 0)                                           ' if not empty
    return str2dec(@gpsrslt[0], 2)                              ' return month                              
  else
    return -1                                                   ' error

  
pub s_year

'' Current year as z-string: "00".."99"
'' -- returns pointer to result string

  s_date                                                        ' get date field
  bytemove(@gpsrslt, @gpsrslt[4], 2)                            ' move year
  gpsrslt[2] := 0                                               ' terminate 

  return @gpsrslt                                               ' return pointer


pub n_year 

'' Current month as decimal value, 0..99
'' -- returns -1 if gps string is invalid  

  s_year                                                        ' get year string
  if (gpsrslt[0] > 0)                                           ' if not empty
    return str2dec(@gpsrslt[0], 2)                              ' return year                              
  else
    return -1                                                   ' error


pub s_latitude

'' Latitude as z-string in the form "ddmm.ssss X"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result
  
  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data? 
    gps_fcopy(@gpsrslt, @rmcwork, 3)                            '  get latitude field
    gpsrslt[9] := " "                                           '  remove termination
    gps_fcopy(@gpsrslt[10], @rmcwork, 4)                        '  get hemisphere       

  return @gpsrslt                                               ' return pointer
  

pub n_latsign

'' Returns hemisphere as number
'' -- 1 for N, -1 for S

  s_latitude                                                    ' get latitude
  if (gpsrslt[10] == "S")                                       ' check hemisphere
    return -1
  else
    return 1

  
pub s_latd

'' Latitude degrees as z-string in the form "00".."90"
'' -- returns pointer to result string

  s_latitude                                                    ' get latitude
  gpsrslt[2] := 0                                               ' terminate after degrees 

  return @gpsrslt                                               ' return pointer


pub n_latd  

'' Latitude degrees as decimal value, 0..90

  s_latitude                                                    ' get latitude
  
  return str2dec(@gpsrslt, 2)                                   ' extract degrees
  

pub s_latm

'' Latitude minutes as z-string in the form "00".."59" 
'' -- returns pointer to result string

  s_latitude                                                    ' get latitude
  bytemove(@gpsrslt[0], @gpsrslt[2], 2)                         ' extract minutes
  gpsrslt[2] := 0                                               ' terminate after minutes 
  
  return @gpsrslt                                               ' return pointer


pub n_latm

'' Latitude minutes as decimal value, 0..59

  s_latitude                                                    ' get latitude
  
  return str2dec(@gpsrslt[2], 2)                                ' extract minutes

  
pub n_lats

'' Latitude seconds as decimal value, 0..59

  s_latitude                                                    ' get latitude
  
  return str2dec(@gpsrslt[5], 4) * 60 / 10_000                  ' return seconds                                                    


pub s_longitude

'' Longitude as z-string in the form "dddmm.ssss X"
'' -- returns pointer to result string

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result
  
  if (strncmp(@RMC_HDR, @rmcwork, 6) == 0)                      ' have gps data? 
    gps_fcopy(@gpsrslt, @rmcwork, 5)                            '  get latitude field
    gpsrslt[10] := " "                                          '  remove termination
    gps_fcopy(@gpsrslt[11], @rmcwork, 6)                        '  get hemisphere       

  return @gpsrslt                                               ' return pointer
  

pub n_lonsign

'' Longitude direction as value
'' -- 1 for E, -1 for W

  s_longitude                                                   ' get latitude
  if (gpsrslt[11] == "W")                                       ' check direction
    return -1
  else
    return 1

  
pub s_lond

'' Longitude degrees as z-string in the form "000".."180"
'' -- returns pointer to result string

  s_longitude                                                   ' get latitude
  gpsrslt[3] := 0                                               ' terminate after degrees 

  return @gpsrslt                                               ' return pointer

  
pub n_lond

'' Longitude degrees as decimal value, 0..180

  s_longitude                                                   ' get latitude
  return str2dec(@gpsrslt, 3)                                   ' extract degrees

  
pub s_lonm

'' Longitude minutes as z-string in the form "00".."59" 
'' -- returns pointer to result string

  s_longitude                                                   ' get latitude
  bytemove(@gpsrslt[0], @gpsrslt[3], 3)                         ' extract minutes
  gpsrslt[2] := 0                                               ' terminate after minutes 
  
  return @gpsrslt                                               ' return pointer


pub n_lonm  

'' Longitude minutes as decimal value, 0..59

  s_longitude                                                   ' get latitude
  
  return str2dec(@gpsrslt[3], 2)                                ' extract minutes

  
pub n_lons 

'' Longitude seconds as decimal value, 0..59

  s_longitude                                                   ' get latitude
  
  return str2dec(@gpsrslt[6], 4) * 60 / 10_000                  ' return seconds


pub s_speedk

'' Speed in knots as z-string: "0.0".."999.9"

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result
  gps_fcopy(@gpsrslt, @rmcwork, 7)                              ' get field 7

  return @gpsrslt                                               ' return pointer


pub n_speedk | p

'' Speed in 0.1 knots as decimal value, 0..9999

  s_speedk                                                      ' get speed string
  p := instr(@gpsrslt, ".")                                     ' find dpoint
  if (p => 0)
    gpsrslt[p] := gpsrslt[p+1]                                  ' move tenths char
    gpsrslt[p+1] := 0                                           ' terminate

  return str2dec(@gpsrslt, 4)                                   ' return 0.1 knots   


pub n_speedm

'' Speed in 0.1 mph as decimal value, 0..~8,689
'' -- 1 mph = 0.868976242 knots
  
   return (n_speedk * 868_976 / 1_000_000)                      ' convert to 0.1 mph                      
  

pub s_bearing

'' Bearing in degrees as z-string: "0.0".."359.9"

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result
  gps_fcopy(@gpsrslt, @rmcwork, 8)                              ' get field 8

  return @gpsrslt                                               ' return pointer


pub n_bearing | p 

'' Bearing in 0.1 degrees as decimal value, 0..3599

  s_bearing                                                     ' get bearing string
  p := instr(@gpsrslt, ".")                                     ' find dpoint
  if (p => 0)
    gpsrslt[p] := gpsrslt[p+1]                                  ' move tenths char
    gpsrslt[p+1] := 0                                           ' terminate

  return str2dec(@gpsrslt, strsize(@gpsrslt))                   ' return bearing 

   
pub s_altm

'' Altitude in meters as z-string, "0.0".."9999.9"

  bytefill(@gpsrslt, 0, RSLT_SIZE)                              ' clear result
  gps_fcopy(@gpsrslt, @ggawork, 9)                              ' get field 9

  return @gpsrslt                                               ' return pointer


pub n_altm | len

'' Altitude in 0.1 meters as decimal value, 0..99999

  s_altm                                                        ' get altitude string
  len := strsize(@gpsrslt)                                      ' get length
  gpsrslt[len-2] := gpsrslt[len-1]                              ' remove decimal point
  gpsrslt[len-1] := 0                                           ' terminate

  return str2dec(@gpsrslt, 6)                                   ' return 0.1 meters 


pub n_altf

'' Altitude in 0.1 feet as decimal value, 0..~30480  
'' -- 1 foot = 0.3048 meters

  return (n_altm * 3_048 / 10_000)                              ' return 0.1 feet


pub rslt_pntr

'' Returns pointer to GPS result string
'' -- allows access for external applications

  return @gpsrslt


pub rslt_copy(dest)

'' Copies contents of result string to destination
'' -- allows parent object to make copy of last result

  bytemove(dest, @gpsrslt, strsize(@gpsrslt))

  return dest                                                   ' return pointer

  
pub str2dec(spntr, n) | dec, c

'' Returns [positive] decimal value of string at spntr

  dec := 0                                                      ' initialize result

  repeat n
    c := byte[spntr++]                                          ' get character
    if (c < "0") or (c > "9")                                   ' if non digit
      quit
    else
      dec *= 10                                                 ' adjust for new digit
      dec += (c - "0")                                          ' add new digit

  return dec                                                    ' return result  


pri gps_fcopy(dest, src, fn) | idx1, idx2, c

'' Copies gps string in (0-indexed) field number (fn) from src to dest

  idx1 := field_idx(fn, src)                                    ' find start
  idx2 := 0 
  
  if (idx1 => 0)                                                ' if valid
    repeat                                                      ' copy field
      c := byte[src][idx1++]                                    ' get source character                                  
      if (c <> ",") and (c <> "*") and (c <> 13)                ' if not field terminator
        byte[dest][idx2++] := c                                 ' add to destination
      else
        quit
  else
    idx2 := 0                                                   ' empty strin on invalid field #
       
  byte[dest][idx2] := 0                                         ' add string terminator

  return dest                                                   ' return result pntr

  
pri field_idx(fn, spntr) | idx, c

'' Returns position index of field number, fn (0+)

  idx := 0

  if (fn > 0)                                                   ' if not 1st field
    repeat while fn
      c := byte[spntr][idx++]
      if (c == ",")                                             ' if separator
        fn -= 1                                                 '  update field count
      if (c == "*") or (c == 13)                                ' if end of string
        idx := -1                                               '  error
        quit

  return idx
  

pri s_insert(c, pos, spntr) | idx

'' Inserts c at pos in string at spntr
'' -- string should be shorter than buffer by at least one character

  repeat idx from strsize(spntr) to pos                         ' work backward
    byte[spntr][idx+1] := byte[spntr][idx]                      ' create space
  byte[spntr][pos] := c                                         ' insert character

  
pri strncopy(dest, src, n) | c

'' Copies (up to) n characters from src to dest
'' -- terminates on 0 or CR for GPS strings

  repeat n
    c := byte[src++]                                            ' get byte from source
    if (c == 13) or (c == 10)                                   ' CR and LF to 0
      c := 0
    byte[dest++] := c                                           ' copy to destination
    if (c == 0)                                                 ' if at end
      quit                                                      '   quit


pri strncmp(s1, s2, n) | idx

'' Compare strings, up to n characters
'' -- will terminate on 0 in string(s)

  repeat idx from 0 to n-1                                      ' loop through length
    if (byte[s1][idx] == byte[s2][idx])                         ' if chars equal
      if (byte[s1][idx] == 0) or (idx == n-1)                   '  if at end
        return 0                                                '   return equality
    else
      quit                                                      ' no, exit

  return byte[s1][idx] - byte[s2][idx]                          ' return comparison  


pri instr(str, c) | len, pos

'' Returns position of c in string
'' -- if not found

  len := strsize(str)
  pos := 0
  
  repeat len
    if (byte[str++] == c)
      quit
    else
      pos += 1

  if (pos < len)
    return pos
  else
    return -1 

     
pri parse_gps | ok, c, len

'' Pulls characters from UART buffer, moves to target GPS buffer
'' -- runs in separate cog; do not call as standard method

  repeat
    ok := true                                                  ' assume ok
    
    bytefill(@gpswork, 0, WORK_SIZE)                            ' clear workspace
    repeat                                                      
      c := rxtime(rxtimeout)                                    ' get char from stream 
      if (c < 0)                                                ' if timeout
        ok := false                                             '  mark as bad
        quit                                                    '  abort                                          
    until (c == "$")                                            ' done when $ located

    if ok                                                       ' if no timeout
      len := 0                                                  ' reset string length
      repeat
        c := rxtime(rxtimeout)                                  ' get char from stream
        if (c < 0)                                              ' if timeout
          ok := false                                           '  mark as bad
          quit                                                  '  abort
        if (c <> 13)                                            ' if at end
          gpswork[len++] := c                                   ' move to workspace
        else
          quit
          
    if ok                                                       ' if no timeout
      if (strncmp(@RMC_HDR, @gpswork, 6) == 0)                  ' $GPRMC string?
        bytemove(@rmcwork, @gpswork, len)                       '  yes, move to buffer
      elseif (strncmp(@GGA_HDR, @gpswork, 6) == 0)              ' $GPGGA string?
        bytemove(@ggawork, @gpswork, len)                       '  yes, move to buffer  


pri rxtime(ms) | t, c

'' Pulls c from receive buffer if available within ms milliseconds
'' -- will return -1 if nothing in buffer (e.g., GPS disconnected)
'' -- updates global hasgps flag

  t := cnt
  repeat until ((c := rx) => 0) or ((cnt - t) / (clkfreq / 1_000) > ms)

  hasgpsflag := (c => 0)                                        ' mark availability flag
  
  return c


pri rx | c

'' Pulls c from receive buffer if available
'' -- returns -1 if buffer empty

  c := -1                                                       ' assume empty

  if (rxtail <> rxhead)                                         ' if char available
    c := rxbuf[rxtail]                                          ' get it
    rxtail := (rxtail + 1) & (BUF_SIZE-1)                       ' update tail pointer

  return c
 

dat

                        org     0

rxserial                mov     dira, #0                        ' all inputs

                        mov     tmp1, par                       ' start of parameters
                        rdlong  tmp2, tmp1                      ' get rx pin
                        mov     rxmask, #1                      ' create pin mask
                        shl     rxmask, tmp2

                        add     tmp1, #4
                        rdlong  rxbit1x0, tmp1                  ' read ticks/bit
                        cmps    rxbit1x0, #0            wc      ' check for inverted
                        muxc    mflag, #1                       ' save mode
                        abs     rxbit1x0, rxbit1x0              ' remove sign
                        mov     rxbit1x5, rxbit1x0              ' create ticks/1.5 bits
                        shr     rxbit1x5, #1
                        add     rxbit1x5, rxbit1x0

                        add     tmp1, #4
                        mov     rxheadpntr, tmp1                ' save addres of rxhead

                        add     tmp1, #8                        ' skip over tails
                        rdlong  rxbufpntr, tmp1                 ' save addres of rxbuf[0]

receive                 mov     rxwork, #0                      ' clear work var
                        mov     rxcount, #8                     ' rx eight bits
                        mov     rxtimer, rxbit1x5               ' set timer to 1.5 bits
                        
waitstart               test    mflag, #1               wz      ' check mode
        if_z            waitpne rxmask, rxmask                  ' wait for falling edge
        if_nz           waitpeq rxmask, rxmask                  ' wait for rising edge  
                        add     rxtimer, cnt                    ' sync with system counter

rxbit                   waitcnt rxtimer, rxbit1x0               ' hold for middle of bit
                        test    rxmask, ina             wc      ' rx --> c
                        shr     rxwork, #1                      ' prep for new bit
                        muxc    rxwork, #%1000_0000             ' c --> rxwork.7
                        djnz    rxcount, #rxbit                 ' update bit count
                        waitcnt rxtimer, #0                     ' let last bit finish

        if_nz           xor     rxwork, #$FF                    ' invert if needed 

putbuf                  rdlong  tmp1, rxheadpntr                ' tmp1 := rxhead
                        add     tmp1, rxbufpntr                 ' tmp1 := rxbuf[rxhead]
                        wrbyte  rxwork, tmp1                    ' rxbuf[rxhead] := rxwork
                        sub     tmp1, rxbufpntr                 ' tmp1 := rxhead 
                        add     tmp1, #1                        ' inc tmp1
                        and     tmp1, #(BUF_SIZE-1)             ' wrap around if needed
                        wrlong  tmp1, rxheadpntr                ' rxhead := tmp1

                        jmp     #receive 

' -------------------------------------------------------------------------------------------------

mflag                   long    0                               ' mode flag (1 = inverted)

rxmask                  res     1                               ' mask for rx pin
rxbit1x0                res     1                               ' ticks per bit
rxbit1x5                res     1                               ' ticks per 1.5 bits
rxheadpntr              res     1                               ' address of head position
rxbufpntr               res     1                               ' address of rxbuf[0]

rxwork                  res     1                               ' rx byte input
rxcount                 res     1                               ' bits to receive
rxtimer                 res     1                               ' timer for bit sampling

tmp1                    res     1
tmp2                    res     1 
                                 
                        fit     $1F0

                                               
dat

{{

  Terms of Use: MIT License

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

}}