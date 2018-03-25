PUB main
  coginit(0, @entry, 0)
DAT
	org	0
entry
	mov	arg1, par wz
 if_ne	jmp	#spininit
	mov	pc, $+2
	call	#LMM_CALL_FROM_COG
	long	@@@_StringToFloat
cogexit
	cogid	arg1
	cogstop	arg1
spininit
	mov	sp, arg1
	rdlong	objptr, sp
	add	sp, #4
	rdlong	pc, sp
	wrlong	ptr_hubexit_, sp
	add	sp, #4
	jmp	#LMM_LOOP
LMM_LOOP
    rdlong LMM_i1, pc
    add    pc, #4
LMM_i1
    nop
    rdlong LMM_i2, pc
    add    pc, #4
LMM_i2
    nop
    rdlong LMM_i3, pc
    add    pc, #4
LMM_i3
    nop
    rdlong LMM_i4, pc
    add    pc, #4
LMM_i4
    nop
LMM_jmptop
    jmp    #LMM_LOOP
pc
    long @@@hubentry
lr
    long 0
hubretptr
    long @@@hub_ret_to_cog
LMM_CALL
    mov    lr, pc
    add    lr, #4
    wrlong lr, sp
    add    sp, #4
    ' fall through
LMM_JUMP
    rdlong pc, pc
    jmp    #LMM_LOOP
LMM_CALL_FROM_COG
    wrlong  hubretptr, sp
    add     sp, #4
    jmp  #LMM_LOOP
LMM_CALL_FROM_COG_ret
    ret
LMM_FCACHE_LOAD
    rdlong COUNT, pc
    add    pc, #4
    mov    ADDR, pc
    sub    LMM_ADDR, pc
    tjz    LMM_ADDR, #a_fcachegoaddpc
    movd   a_fcacheldlp, #LMM_FCACHE_START
    shr    COUNT, #2
a_fcacheldlp
    rdlong 0-0, pc
    add    pc, #4
    add    a_fcacheldlp,inc_dest1
    djnz   COUNT,#a_fcacheldlp
    ror    a_fcacheldlp, #9
    movd   a_fcachecopyjmp, a_fcacheldlp
    rol    a_fcacheldlp, #9
a_fcachecopyjmp
    mov    0-0, LMM_jmptop
a_fcachego
    mov    LMM_ADDR, ADDR
    jmpret LMM_RET,#LMM_FCACHE_START
a_fcachegoaddpc
    add    pc, COUNT
    jmp    #a_fcachego
LMM_FCACHE_LOAD_ret
    ret
inc_dest1
    long (1<<9)
LMM_LEAVE_CODE
    jmp LMM_RET
LMM_ADDR
    long 0
ADDR
    long 0
COUNT
    long 0

multiply_
	mov	itmp2_, muldiva_
	xor	itmp2_, muldivb_
	abs	muldiva_, muldiva_
	abs	muldivb_, muldivb_
	mov	result1, #0
	mov	itmp1_, #32
	shr	muldiva_, #1 wc
mul_lp_
 if_c	add	result1, muldivb_ wc
	rcr	result1, #1 wc
	rcr	muldiva_, #1 wc
	djnz	itmp1_, #mul_lp_
	shr	itmp2_, #31 wz
 if_nz	neg	result1, result1
 if_nz	neg	muldiva_, muldiva_ wz
 if_nz	sub	result1, #1
	mov	muldivb_, result1
multiply__ret
	ret

' pri longfill(ptr, val, count)
__system__longfill
'   repeat count
	cmps	arg3, #0 wz
 if_e	jmp	#L__90018
L__90019
'     long[ptr] := val
	wrlong	arg2, arg1
'     ptr += 4
	add	arg1, #4
	djnz	arg3, #L__90019
L__90018
__system__longfill_ret
	ret

' pri longmove(dst, src, count)
__system__longmove
'   repeat count
	cmps	arg3, #0 wz
 if_e	jmp	#L__90022
L__90023
'     long[dst] := long[src]
	rdlong	_tmp001_, arg2
	wrlong	_tmp001_, arg1
'     dst += 4
	add	arg1, #4
'     src += 4
	add	arg2, #4
	djnz	arg3, #L__90023
L__90022
__system__longmove_ret
	ret

fp
	long	0
imm_1036831949_
	long	1036831949
imm_1092616192_
	long	1092616192
imm_2147483648_
	long	-2147483648
imm_4294967273_
	long	-23
imm_536870912_
	long	536870912
imm_8388607_
	long	8388607
itmp1_
	long	0
itmp2_
	long	0
objptr
	long	@@@objmem
ptr_hubexit_
	long	@@@hubexit
result1
	long	0
sp
	long	@@@stackspace
COG_BSS_START
	fit	496
hub_ret_to_cog
	jmp	#LMM_CALL_FROM_COG_ret
hubentry

' 
' ''***************************************
' ''*  Floating-Point <-> Strings         *
' ''*  Single-precision IEEE-754          *
' ''*  Author: Chip Gracey                *
' ''*  Copyright (c) 2006 Parallax, Inc.  *
' ''*  See end of file for terms of use.  *
' ''***************************************
' 
' VAR
' 
'   long  p, digits, exponent, integer, tens, zeros,  precision
'   long  positive_chr, decimal_chr, thousands_chr, thousandths_chr
'   byte  float_string[20]
' 
' 
' OBJ
' 
'   math : "tiny.math.float"
' 
' PUB StringToFloat( strptr ) : f | int, sign, dmag, mag, get_exp, b
_StringToFloat
	wrlong	fp, sp
	add	sp, #4
	mov	fp, sp
	add	sp, #40
' {{
	mov	StringToFloat_tmp001_, #0
	wrlong	StringToFloat_tmp001_, fp
'     get all the digits as if this is an integer (but track the exponent)
'     int := sign := dmag := mag := get_exp := 0
' }}
'   longfill( @int, 0, 5 )
	add	fp, #8
	mov	arg1, fp
	sub	fp, #8
	mov	arg2, #0
	mov	arg3, #5
	call	#__system__longfill
'   repeat
L__0021
	add	fp, #4
	rdlong	StringToFloat_tmp001_, fp
	mov	StringToFloat_tmp002_, StringToFloat_tmp001_
	add	StringToFloat_tmp002_, #1
	wrlong	StringToFloat_tmp002_, fp
	rdbyte	StringToFloat_tmp003_, StringToFloat_tmp001_
	add	fp, #24
	wrlong	StringToFloat_tmp003_, fp
	mov	StringToFloat_tmp004_, StringToFloat_tmp003_
	sub	fp, #28
	cmps	StringToFloat_tmp004_, #45 wz
 if_ne	add	pc, #4*(L__0024 - ($+1))
'     case b := byte[strptr++]
'       "-": sign := $8000_0000
	mov	StringToFloat_tmp005_, imm_2147483648_
	add	fp, #12
	wrlong	StringToFloat_tmp005_, fp
	sub	fp, #12
	rdlong	pc,pc
	long	@@@L__0023
L__0024
	add	fp, #28
	rdlong	StringToFloat_tmp005_, fp
	sub	fp, #28
	cmps	StringToFloat_tmp005_, #43 wz
 if_e	rdlong	pc,pc
	long	@@@L__0023
	add	fp, #28
	rdlong	StringToFloat_tmp006_, fp
	sub	fp, #28
	mov	StringToFloat_tmp007_, #48
	mov	StringToFloat_tmp008_, #57
	maxs	StringToFloat_tmp007_, #57
	mins	StringToFloat_tmp008_, #48
	cmps	StringToFloat_tmp007_, StringToFloat_tmp006_ wc,wz
 if_be	cmps	StringToFloat_tmp006_, StringToFloat_tmp008_ wc,wz
 if_a	add	pc, #4*(L__0026 - ($+1))
'       "+": ' just ignore, but allow
'       "0".."9":
'            int := int*10 + b - "0"
	add	fp, #8
	rdlong	StringToFloat_tmp011_, fp
	mov	StringToFloat_tmp009_, StringToFloat_tmp011_
	shl	StringToFloat_tmp009_, #2
	add	StringToFloat_tmp009_, StringToFloat_tmp011_
	shl	StringToFloat_tmp009_, #1
	add	fp, #20
	rdlong	StringToFloat_tmp012_, fp
	add	StringToFloat_tmp009_, StringToFloat_tmp012_
	sub	StringToFloat_tmp009_, #48
	sub	fp, #20
	wrlong	StringToFloat_tmp009_, fp
'            mag += dmag
	add	fp, #12
	rdlong	StringToFloat_tmp009_, fp
	sub	fp, #4
	rdlong	StringToFloat_tmp010_, fp
	add	StringToFloat_tmp009_, StringToFloat_tmp010_
	add	fp, #4
	wrlong	StringToFloat_tmp009_, fp
	sub	fp, #20
	rdlong	pc,pc
	long	@@@L__0023
L__0026
	add	fp, #28
	rdlong	StringToFloat_tmp009_, fp
	sub	fp, #28
	cmps	StringToFloat_tmp009_, #46 wz
 if_ne	add	pc, #4*(L__0027 - ($+1))
'       ".": dmag := -1
	neg	StringToFloat_tmp010_, #1
	add	fp, #16
	wrlong	StringToFloat_tmp010_, fp
	sub	fp, #16
	rdlong	pc,pc
	long	@@@L__0023
L__0027
'       other: ' either done, or about to do exponent
'            if get_exp
	add	fp, #24
	rdlong	StringToFloat_tmp010_, fp wz
	sub	fp, #24
 if_e	add	pc, #4*(L__0029 - ($+1))
'              ' we just finished processing the exponent
'              if sign
	add	fp, #12
	rdlong	StringToFloat_tmp010_, fp wz
	sub	fp, #12
 if_e	add	pc, #4*(L__0030 - ($+1))
'                int := -int
	add	fp, #8
	rdlong	StringToFloat_tmp010_, fp
	neg	StringToFloat_tmp010_, StringToFloat_tmp010_
	wrlong	StringToFloat_tmp010_, fp
	sub	fp, #8
L__0030
'              mag += int
	add	fp, #20
	rdlong	StringToFloat_tmp010_, fp
	sub	fp, #12
	rdlong	StringToFloat_tmp011_, fp
	add	StringToFloat_tmp010_, StringToFloat_tmp011_
	add	fp, #12
	wrlong	StringToFloat_tmp010_, fp
	sub	fp, #20
'              quit
	add	pc, #4*(L__0022 - ($+1))
L__0029
'            else
'              ' convert int to a (signed) float
'              f := math.FFloat( int ) | sign
	add	fp, #8
	rdlong	StringToFloat_tmp011_, fp
	sub	fp, #8
	add	sp, #12
	wrlong	StringToFloat_tmp011_, sp
	sub	sp, #12
	add	objptr, #64
	jmp	#LMM_CALL
	long	@@@_tiny.math.float_FFloat
	sub	objptr, #64
	mov	StringToFloat_tmp010_, result1
	add	fp, #12
	rdlong	StringToFloat_tmp013_, fp
	sub	fp, #12
	or	StringToFloat_tmp010_, StringToFloat_tmp013_
	wrlong	StringToFloat_tmp010_, fp
'              ' should we continue?
'              if (b == "E") or (b == "e")
	add	fp, #28
	rdlong	StringToFloat_tmp010_, fp
	sub	fp, #28
	cmps	StringToFloat_tmp010_, #69 wz
 if_e	add	pc, #4*(L__0033 - ($+1))
	add	fp, #28
	rdlong	StringToFloat_tmp011_, fp
	sub	fp, #28
	cmps	StringToFloat_tmp011_, #101 wz
 if_ne	add	pc, #4*(L__0032 - ($+1))
L__0033
'                ' int := sign := dmag := 0
'                longfill( @int, 0, 3 )
	add	fp, #8
	mov	arg1, fp
	sub	fp, #8
	mov	arg2, #0
	mov	arg3, #3
	call	#__system__longfill
'                get_exp := 1
	mov	StringToFloat_tmp010_, #1
	add	fp, #24
	wrlong	StringToFloat_tmp010_, fp
	sub	fp, #24
	add	pc, #4*(L__0034 - ($+1))
L__0032
'              else
'                quit
	add	pc, #4*(L__0022 - ($+1))
L__0034
L__0023
	rdlong	pc,pc
	long	@@@L__0021
L__0022
'   ' Exp10 is the weak link...uses the Log table in P1 ROM
'   'f := FMul( f, Exp10( FFloat( mag ) ) )
'   ' use these loops for more precision (slower for large exponents, positive or negative)
'   b := 0.1
	mov	StringToFloat_tmp001_, imm_1036831949_
	add	fp, #28
	wrlong	StringToFloat_tmp001_, fp
'   if mag > 0
	sub	fp, #8
	rdlong	StringToFloat_tmp001_, fp
	sub	fp, #20
	cmps	StringToFloat_tmp001_, #0 wc,wz
 if_be	add	pc, #4*(L__0035 - ($+1))
'     b := 10.0
	mov	StringToFloat_tmp001_, imm_1092616192_
	add	fp, #28
	wrlong	StringToFloat_tmp001_, fp
	sub	fp, #28
L__0035
'   repeat ||mag
	add	fp, #20
	rdlong	StringToFloat_tmp001_, fp
	sub	fp, #20
	abs	_StringToFloat__idx__0001, StringToFloat_tmp001_
	cmps	_StringToFloat__idx__0001, #0 wz
 if_e	add	pc, #4*(L__0038 - ($+1))
L__0039
'     f := math.FMul ( f, b )
	rdlong	StringToFloat_tmp002_, fp
	add	fp, #28
	rdlong	StringToFloat_tmp003_, fp
	sub	fp, #28
	add	sp, #12
	wrlong	StringToFloat_tmp002_, sp
	add	sp, #4
	wrlong	StringToFloat_tmp003_, sp
	sub	sp, #16
	add	objptr, #64
	jmp	#LMM_CALL
	long	@@@_tiny.math.float_FMul
	sub	objptr, #64
	mov	StringToFloat_tmp004_, result1
	wrlong	StringToFloat_tmp004_, fp
	djnz	_StringToFloat__idx__0001, #LMM_JUMP
	long	@@@L__0039
L__0038
' 
' PUB FloatToString(Single) : StringPtr
' 
' ''Convert floating-point number to string
' ''
' ''  entry:
' ''      Single = floating-point number
' ''
' ''  exit:
' ''      StringPtr = pointer to resultant z-string
' ''
' ''  Magnitudes below 1e+12 and within 1e-12 will be expressed directly;
' ''  otherwise, scientific notation will be used.
' ''
' ''  examples                 results
' ''  -----------------------------------------
' ''  FloatToString(0.0)       "0"
' ''  FloatToString(1.0)       "1"
' ''  FloatToString(-1.0)      "-1"
' ''  FloatToString(^^2.0)     "1.414214"
' ''  FloatToString(2.34e-3)   "0.00234"
' ''  FloatToString(-1.5e-5)   "-0.000015"
' ''  FloatToString(2.7e+6)    "2700000"
' ''  FloatToString(1e11)      "100000000000"
' ''  FloatToString(1e12)      "1.000000e+12"
' ''  FloatToString(1e-12)     "0.000000000001"
' ''  FloatToString(1e-13)     "1.000000e-13"
' 
'   'perform initial setup
'   StringPtr := Setup(Single)
' 
'   'eliminate trailing zeros
'   if integer
'     repeat until integer // 10
'       integer /= 10
'       tens /= 10
'       digits--
'   else
'     digits~
' 
'   'express number according to exponent
'   case exponent
'     'in range left of decimal
'     11..0:
'       AddDigits(exponent + 1)
'     'in range right of decimal
'     -1..digits - 13:
'       zeros := -exponent
'       AddDigits(1)
'     'out of range, do scientific notation
'     other:
'       DoScientific
' 
'   'terminate z-string
'   byte[p]~
' 
' 
' PUB FloatToScientific(Single) : StringPtr
' 
' ''Convert floating-point number to scientific-notation string
' ''
' ''  entry:
' ''      Single = floating-point number
' ''
' ''  exit:
' ''      StringPtr = pointer to resultant z-string
' ''
' ''  examples                           results
' ''  -------------------------------------------------
' ''  FloatToScientific(1e-9)            "1.000000e-9"
' ''  FloatToScientific(^^2.0)           "1.414214e+0"
' ''  FloatToScientific(0.00251)         "2.510000e-3"
' ''  FloatToScientific(-0.0000150043)   "-1.500430e-5"
' 
'   'perform initial setup
'   StringPtr := Setup(Single)
' 
'   'do scientific notation
'   DoScientific
' 
'   'terminate z-string
'   byte[p]~
' 
' 
' PUB FloatToMetric(Single, SuffixChr) : StringPtr | x, y
' 
' ''Convert floating-point number to metric string
' ''
' ''  entry:
' ''      Single = floating-point number
' ''      SuffixChr = optional ending character (0=none)
' ''
' ''  exit:
' ''      StringPtr = pointer to resultant z-string
' ''
' ''  Magnitudes within the metric ranges will be expressed in metric
' ''  terms; otherwise, scientific notation will be used.
' ''
' ''  range   name     symbol
' ''  -----------------------
' ''  1e24    yotta    Y
' ''  1e21    zetta    Z
' ''  1e18    exa      E
' ''  1e15    peta     P
' ''  1e12    tera     T
' ''  1e9     giga     G
' ''  1e6     mega     M
' ''  1e3     kilo     k
' ''  1e0     -        -
' ''  1e-3    milli    m
' ''  1e-6    micro    u
' ''  1e-9    nano     n
' ''  1e-12   pico     p
' ''  1e-15   femto    f
' ''  1e-18   atto     a
' ''  1e-21   zepto    z
' ''  1e-24   yocto    y
' ''
' ''  examples               results
' ''  ------------------------------------
' ''  metric(2000.0, "m")    "2.000000km"
' ''  metric(-4.5e-5, "A")   "-45.00000uA"
' ''  metric(2.7e6, 0)       "2.700000M"
' ''  metric(39e31, "W")     "3.9000e+32W"
' 
'   'perform initial setup
'   StringPtr := Setup(Single)
' 
'   'determine thousands exponent and relative tens exponent
'   x := (exponent + 45) / 3 - 15
'   y := (exponent + 45) // 3
' 
'   'if in metric range, do metric
'   if ||x =< 8
'     'add digits with possible decimal
'     AddDigits(y + 1)
'     'add space
'     byte[p++] := " "
'     'if thousands exponent not 0, add metric indicator
'     if x
'       byte[p++] := metric[x]
'   'if out of metric range, do scientific notation
'   else
'     DoScientific
' 
'   'if SuffixChr not 0, add SuffixChr
'   if SuffixChr
'     byte[p++] := SuffixChr
' 
'   'terminate z-string
'   byte[p]~
' 
' 
' PUB SetPrecision(NumberOfDigits)
' 
' ''Set precision to express floating-point numbers in
' ''
' ''  NumberOfDigits = Number of digits to round to, limited to 1..7 (7=default)
' ''
' ''  examples          results
' ''  -------------------------------
' ''  SetPrecision(1)   "1e+0"
' ''  SetPrecision(4)   "1.000e+0"
' ''  SetPrecision(7)   "1.000000e+0"
' 
'   precision := NumberOfDigits
' 
' 
' PUB SetPositiveChr(PositiveChr)
' 
' ''Set lead character for positive numbers
' ''
' ''  PositiveChr = 0: no character will lead positive numbers (default)
' ''            non-0: PositiveChr will lead positive numbers (ie " " or "+")
' ''
' ''  examples              results
' ''  ----------------------------------------
' ''  SetPositiveChr(0)     "20.07"   "-20.07"
' ''  SetPositiveChr(" ")   " 20.07"  "-20.07"
' ''  SetPositiveChr("+")   "+20.07"  "-20.07"
' 
'   positive_chr := PositiveChr
' 
' 
' PUB SetDecimalChr(DecimalChr)
' 
' ''Set decimal point character
' ''
' ''  DecimalChr = 0: "." will be used (default)
' ''           non-0: DecimalChr will be used (ie "," for Europe)
' ''
' ''  examples             results
' ''  ----------------------------
' ''  SetDecimalChr(0)     "20.49"
' ''  SetDecimalChr(",")   "20,49"
' 
'   decimal_chr := DecimalChr
' 
' 
' PUB SetSeparatorChrs(ThousandsChr, ThousandthsChr)
' 
' ''Set thousands and thousandths separator characters
' ''
' ''  ThousandsChr =
' ''        0: no character will separate thousands (default)
' ''    non-0: ThousandsChr will separate thousands
' ''
' ''  ThousandthsChr =
' ''        0: no character will separate thousandths (default)
' ''    non-0: ThousandthsChr will separate thousandths
' ''
' ''  examples                     results
' ''  -----------------------------------------------------------
' ''  SetSeparatorChrs(0, 0)       "200000000"    "0.000729345"
' ''  SetSeparatorChrs(0, "_")     "200000000"    "0.000_729_345"
' ''  SetSeparatorChrs(",", 0)     "200,000,000"  "0.000729345"
' ''  SetSeparatorChrs(",", "_")   "200,000,000"  "0.000_729_345"
' 
'   thousands_chr := ThousandsChr
'   thousandths_chr := ThousandthsChr
' 
' 
' PRI Setup(single) : stringptr
' 
'  'limit digits to 1..7
'   if precision
'     digits := precision #> 1 <# 7
'   else
'     digits := 7
' 
'   'initialize string pointer
'   p := @float_string
' 
'   'add "-" if negative
'   if single & $80000000
'     byte[p++] := "-"
'   'otherwise, add any positive lead character
'   elseif positive_chr
'     byte[p++] := positive_chr
' 
'   'clear sign and check for 0
'   if single &= $7FFFFFFF
' 
'     'not 0, estimate exponent
'     exponent := ((single << 1 >> 24 - 127) * 77) ~> 8
' 
'     'if very small, bias up
'     if exponent < -32
'       single := math.FMul(single, 1e13)
'       exponent += result := 13
' 
'     'determine exact exponent and integer
'     repeat
'       integer := math.FRound(math.FMul(single, tenf[exponent - digits + 1]))
'       if integer < teni[digits - 1]
'         exponent--
'       elseif integer => teni[digits]
'         exponent++
'       else
'         exponent -= result
'         quit
' 
'   'if 0, reset exponent and integer
'   else
'     exponent~
'     integer~
' 
'   'set initial tens and clear zeros
'   tens := teni[digits - 1]
'   zeros~
' 
'   'return pointer to string
'   stringptr := @float_string
' 
' 
' PRI DoScientific
' 
'   'add digits with possible decimal
'   AddDigits(1)
'   'add exponent indicator
'   byte[p++] := "e"
'   'add exponent sign
'   if exponent => 0
'     byte[p++] := "+"
'   else
'     byte[p++] := "-"
'     ||exponent
'   'add exponent digits
'   if exponent => 10
'     byte[p++] := exponent / 10 + "0"
'     exponent //= 10
'   byte[p++] := exponent + "0"
' 
' 
' PRI AddDigits(leading) | i
' 
'   'add leading digits
'   repeat i := leading
	rdlong	result1, fp
	mov	sp, fp
	sub	sp, #4
	rdlong	fp, sp
_StringToFloat_ret
	sub	sp, #4
	rdlong	pc, sp

' 
' ''***************************************
' ''*  Floating-Point Math                *
' ''*  Single-precision IEEE-754          *
' ''*  Author: Chip Gracey                *
' ''*  Copyright (c) 2006 Parallax, Inc.  *
' ''*  See end of file for terms of use.  *
' ''***************************************
' 
' 
' PUB FFloat(integer) : single | s, x, m
_tiny.math.float_FFloat
	wrlong	fp, sp
	add	sp, #4
	mov	fp, sp
	add	sp, #20
' 
' ''Convert integer to float
' 
'   if m := ||integer             'absolutize mantissa, if 0, result 0
	add	fp, #4
	rdlong	tiny.math.float_FFloat_tmp001_, fp
	abs	tiny.math.float_FFloat_tmp001_, tiny.math.float_FFloat_tmp001_
	add	fp, #12
	wrlong	tiny.math.float_FFloat_tmp001_, fp
	mov	tiny.math.float_FFloat_tmp002_, tiny.math.float_FFloat_tmp001_ wz
	sub	fp, #16
 if_e	add	pc, #4*(L__0040 - ($+1))
'     s := integer >> 31          'get sign
	add	fp, #4
	rdlong	tiny.math.float_FFloat_tmp001_, fp
	shr	tiny.math.float_FFloat_tmp001_, #31
	add	fp, #4
	wrlong	tiny.math.float_FFloat_tmp001_, fp
'     x := >|m - 1                'get exponent
	add	fp, #8
	rdlong	tiny.math.float_FFloat_tmp003_, fp
	sub	fp, #16
	mov	tiny.math.float_FFloat_tmp002_, #32
	call	#LMM_FCACHE_LOAD
	long	(@@@L__0050-@@@L__0041)
L__0041
	shl	tiny.math.float_FFloat_tmp003_, #1 wc
 if_nc	djnz	tiny.math.float_FFloat_tmp002_, #LMM_FCACHE_START + (L__0041 - L__0041)
L__0050
	sub	tiny.math.float_FFloat_tmp002_, #1
	add	fp, #12
	wrlong	tiny.math.float_FFloat_tmp002_, fp
'     m <<= 31 - x                'msb-justify mantissa
	add	fp, #4
	rdlong	tiny.math.float_FFloat_tmp001_, fp
	mov	tiny.math.float_FFloat_tmp002_, #31
	sub	fp, #4
	rdlong	tiny.math.float_FFloat_tmp003_, fp
	sub	tiny.math.float_FFloat_tmp002_, tiny.math.float_FFloat_tmp003_
	shl	tiny.math.float_FFloat_tmp001_, tiny.math.float_FFloat_tmp002_
	add	fp, #4
	wrlong	tiny.math.float_FFloat_tmp001_, fp
'     m >>= 2                     'bit29-justify mantissa
	shr	tiny.math.float_FFloat_tmp001_, #2
	wrlong	tiny.math.float_FFloat_tmp001_, fp
' 
'     return Pack(@s)             'pack result
	sub	fp, #8
	mov	tiny.math.float_FFloat_tmp002_, fp
	sub	fp, #8
	add	sp, #12
	wrlong	tiny.math.float_FFloat_tmp002_, sp
	sub	sp, #12
	jmp	#LMM_CALL
	long	@@@_tiny.math.float_Pack
	rdlong	pc,pc
	long	@@@L__0017
L__0040
' 
' PUB FRound(single) : integer
' 
' ''Convert float to rounded integer
' 
'   return FInteger(single, 1)    'use 1/2 to round
' 
' 
' PUB FTrunc(single) : integer
' 
' ''Convert float to truncated integer
' 
'   return FInteger(single, 0)    'use 0 to round
' 
' 
' PUB FNeg(singleA) : single
' 
' ''Negate singleA
' 
'   return singleA ^ $8000_0000   'toggle sign bit
' 
' 
' PUB FAbs(singleA) : single
' 
' ''Absolute singleA
' 
'   return singleA & $7FFF_FFFF   'clear sign bit
' 
' 
' PUB FSqrt(singleA) : single | s, x, m, root
' 
' ''Compute square root of singleA
' 
'   if singleA > 0                'if a =< 0, result 0
' 
'     Unpack(@s, singleA)         'unpack input
' 
'     m >>= !x & 1                'if exponent even, shift mantissa down
'     x ~>= 1                     'get root exponent
' 
'     root := $4000_0000          'compute square root of mantissa
'     repeat 31
'       result |= root
'       if result ** result > m
'         result ^= root
'       root >>= 1
'     m := result >> 1
' 
'     return Pack(@s)             'pack result
' 
' 
' PUB FAdd(singleA, singleB) : single | sa, xa, ma, sb, xb, mb
' 
' ''Add singleA and singleB
' 
'   Unpack(@sa, singleA)          'unpack inputs
'   Unpack(@sb, singleB)
' 
'   if sa                         'handle mantissa negation
'     -ma
'   if sb
'     -mb
' 
'   result := ||(xa - xb) <# 31   'get exponent difference
'   if xa > xb                    'shift lower-exponent mantissa down
'     mb ~>= result
'   else
'     ma ~>= result
'     xa := xb
' 
'   ma += mb                      'add mantissas
'   sa := ma < 0                  'get sign
'   ||ma                          'absolutize result
' 
'   return Pack(@sa)              'pack result
' 
' 
' PUB FSub(singleA, singleB) : single
' 
' ''Subtract singleB from singleA
' 
'   return FAdd(singleA, FNeg(singleB))
' 
' 
' PUB FMul(singleA, singleB) : single | sa, xa, ma, sb, xb, mb
' 
' ''Multiply singleA by singleB
' 
'   Unpack(@sa, singleA)          'unpack inputs
'   Unpack(@sb, singleB)
' 
'   sa ^= sb                      'xor signs
'   xa += xb                      'add exponents
'   ma := (ma ** mb) << 3         'multiply mantissas and justify
' 
'   return Pack(@sa)              'pack result
' 
' 
' PUB FDiv(singleA, singleB) : single | sa, xa, ma, sb, xb, mb
' 
' ''Divide singleA by singleB
' 
'   Unpack(@sa, singleA)          'unpack inputs
'   Unpack(@sb, singleB)
' 
'   sa ^= sb                      'xor signs
'   xa -= xb                      'subtract exponents
' 
'   repeat 30                     'divide mantissas
	mov	result1, #0
L__0017
	mov	sp, fp
	sub	sp, #4
	rdlong	fp, sp
_tiny.math.float_FFloat_ret
	sub	sp, #4
	rdlong	pc, sp

_tiny.math.float_FMul
	wrlong	fp, sp
	add	sp, #4
	mov	fp, sp
	add	sp, #36
	add	fp, #12
	mov	tiny.math.float_FMul_tmp002_, fp
	sub	fp, #8
	rdlong	tiny.math.float_FMul_tmp003_, fp
	sub	fp, #4
	add	sp, #12
	wrlong	tiny.math.float_FMul_tmp002_, sp
	add	sp, #4
	wrlong	tiny.math.float_FMul_tmp003_, sp
	sub	sp, #16
	jmp	#LMM_CALL
	long	@@@_tiny.math.float_Unpack
	add	fp, #24
	mov	tiny.math.float_FMul_tmp002_, fp
	sub	fp, #16
	rdlong	tiny.math.float_FMul_tmp003_, fp
	sub	fp, #8
	add	sp, #12
	wrlong	tiny.math.float_FMul_tmp002_, sp
	add	sp, #4
	wrlong	tiny.math.float_FMul_tmp003_, sp
	sub	sp, #16
	jmp	#LMM_CALL
	long	@@@_tiny.math.float_Unpack
	add	fp, #12
	rdlong	tiny.math.float_FMul_tmp001_, fp
	add	fp, #12
	rdlong	tiny.math.float_FMul_tmp002_, fp
	xor	tiny.math.float_FMul_tmp001_, tiny.math.float_FMul_tmp002_
	sub	fp, #12
	wrlong	tiny.math.float_FMul_tmp001_, fp
	add	fp, #4
	rdlong	tiny.math.float_FMul_tmp001_, fp
	add	fp, #12
	rdlong	tiny.math.float_FMul_tmp002_, fp
	add	tiny.math.float_FMul_tmp001_, tiny.math.float_FMul_tmp002_
	sub	fp, #12
	wrlong	tiny.math.float_FMul_tmp001_, fp
	add	fp, #4
	rdlong	muldiva_, fp
	add	fp, #12
	rdlong	muldivb_, fp
	sub	fp, #32
	call	#multiply_
	mov	tiny.math.float_FMul_tmp001_, muldivb_
	shl	tiny.math.float_FMul_tmp001_, #3
	add	fp, #20
	wrlong	tiny.math.float_FMul_tmp001_, fp
	sub	fp, #8
	mov	tiny.math.float_FMul_tmp002_, fp
	sub	fp, #12
	add	sp, #12
	wrlong	tiny.math.float_FMul_tmp002_, sp
	sub	sp, #12
	jmp	#LMM_CALL
	long	@@@_tiny.math.float_Pack
	mov	sp, fp
	sub	sp, #4
	rdlong	fp, sp
_tiny.math.float_FMul_ret
	sub	sp, #4
	rdlong	pc, sp

'     result <<= 1
'     if ma => mb
'       ma -= mb
'       result++
'     ma <<= 1
'   ma := result
' 
'   return Pack(@sa)              'pack result
' 
' 
' PRI FInteger(a, r) : integer | s, x, m
' 
' 'Convert float to rounded/truncated integer
' 
'   Unpack(@s, a)                 'unpack input
' 
'   if x => -1 and x =< 30        'if exponent not -1..30, result 0
'     m <<= 2                     'msb-justify mantissa
'     m >>= 30 - x                'shift down to 1/2-lsb
'     m += r                      'round (1) or truncate (0)
'     m >>= 1                     'shift down to lsb
'     if s                        'handle negation
'       -m
'     return m                    'return integer
' 
' 
' PRI Unpack(pointer, single) | s, x, m
_tiny.math.float_Unpack
	wrlong	fp, sp
	add	sp, #4
	mov	fp, sp
	add	sp, #24
' 
	mov	tiny.math.float_Unpack_tmp001_, #0
	wrlong	tiny.math.float_Unpack_tmp001_, fp
' 'Unpack floating-point into (sign, exponent, mantissa) at pointer
' 
'   s := single >> 31             'unpack sign
	add	fp, #8
	rdlong	tiny.math.float_Unpack_tmp001_, fp
	shr	tiny.math.float_Unpack_tmp001_, #31
	add	fp, #4
	wrlong	tiny.math.float_Unpack_tmp001_, fp
'   x := single << 1 >> 24        'unpack exponent
	sub	fp, #4
	rdlong	tiny.math.float_Unpack_tmp001_, fp
	shl	tiny.math.float_Unpack_tmp001_, #1
	shr	tiny.math.float_Unpack_tmp001_, #24
	add	fp, #8
	wrlong	tiny.math.float_Unpack_tmp001_, fp
'   m := single & $007F_FFFF      'unpack mantissa
	sub	fp, #8
	rdlong	tiny.math.float_Unpack_tmp001_, fp
	and	tiny.math.float_Unpack_tmp001_, imm_8388607_
	add	fp, #12
	wrlong	tiny.math.float_Unpack_tmp001_, fp
' 
'   if x                          'if exponent > 0,
	sub	fp, #4
	rdlong	tiny.math.float_Unpack_tmp001_, fp wz
	sub	fp, #16
 if_e	add	pc, #4*(L__0042 - ($+1))
'     m := m << 6 | $2000_0000    '..bit29-justify mantissa with leading 1
	add	fp, #20
	rdlong	tiny.math.float_Unpack_tmp001_, fp
	shl	tiny.math.float_Unpack_tmp001_, #6
	or	tiny.math.float_Unpack_tmp001_, imm_536870912_
	wrlong	tiny.math.float_Unpack_tmp001_, fp
	sub	fp, #20
	add	pc, #4*(L__0043 - ($+1))
L__0042
'   else
'     result := >|m - 23          'else, determine first 1 in mantissa
	add	fp, #20
	rdlong	tiny.math.float_Unpack_tmp003_, fp
	sub	fp, #20
	mov	tiny.math.float_Unpack_tmp002_, #32
	call	#LMM_FCACHE_LOAD
	long	(@@@L__0051-@@@L__0044)
L__0044
	shl	tiny.math.float_Unpack_tmp003_, #1 wc
 if_nc	djnz	tiny.math.float_Unpack_tmp002_, #LMM_FCACHE_START + (L__0044 - L__0044)
L__0051
	sub	tiny.math.float_Unpack_tmp002_, #23
	wrlong	tiny.math.float_Unpack_tmp002_, fp
'     x := result                 '..adjust exponent
	add	fp, #16
	wrlong	tiny.math.float_Unpack_tmp001_, fp
'     m <<= 7 - result            '..bit29-justify mantissa
	add	fp, #4
	rdlong	tiny.math.float_Unpack_tmp001_, fp
	sub	fp, #20
	mov	tiny.math.float_Unpack_tmp002_, #7
	rdlong	tiny.math.float_Unpack_tmp003_, fp
	sub	tiny.math.float_Unpack_tmp002_, tiny.math.float_Unpack_tmp003_
	shl	tiny.math.float_Unpack_tmp001_, tiny.math.float_Unpack_tmp002_
	add	fp, #20
	wrlong	tiny.math.float_Unpack_tmp001_, fp
	sub	fp, #20
L__0043
' 
'   x -= 127                      'unbias exponent
	add	fp, #16
	rdlong	tiny.math.float_Unpack_tmp001_, fp
	sub	tiny.math.float_Unpack_tmp001_, #127
	wrlong	tiny.math.float_Unpack_tmp001_, fp
' 
'   longmove(pointer, @s, 3)      'write (s,x,m) structure from locals
	sub	fp, #12
	rdlong	arg1, fp
	add	fp, #8
	mov	arg2, fp
	sub	fp, #12
	mov	arg3, #3
	call	#__system__longmove
	rdlong	result1, fp
	mov	sp, fp
	sub	sp, #4
	rdlong	fp, sp
_tiny.math.float_Unpack_ret
	sub	sp, #4
	rdlong	pc, sp

' 
' 
' PRI Pack(pointer) : single | s, x, m
_tiny.math.float_Pack
	wrlong	fp, sp
	add	sp, #4
	mov	fp, sp
	add	sp, #20
' 
	mov	tiny.math.float_Pack_tmp001_, #0
	wrlong	tiny.math.float_Pack_tmp001_, fp
' 'Pack floating-point from (sign, exponent, mantissa) at pointer
' 
'   longmove(@s, pointer, 3)      'get (s,x,m) structure into locals
	add	fp, #8
	mov	arg1, fp
	sub	fp, #4
	rdlong	arg2, fp
	sub	fp, #4
	mov	arg3, #3
	call	#__system__longmove
' 
'   if m                          'if mantissa 0, result 0
	add	fp, #16
	rdlong	tiny.math.float_Pack_tmp001_, fp wz
	sub	fp, #16
 if_e	rdlong	pc,pc
	long	@@@L__0045
' 
'     result := 33 - >|m          'determine magnitude of mantissa
	add	fp, #16
	rdlong	tiny.math.float_Pack_tmp003_, fp
	sub	fp, #16
	mov	tiny.math.float_Pack_tmp002_, #32
	call	#LMM_FCACHE_LOAD
	long	(@@@L__0052-@@@L__0046)
L__0046
	shl	tiny.math.float_Pack_tmp003_, #1 wc
 if_nc	djnz	tiny.math.float_Pack_tmp002_, #LMM_FCACHE_START + (L__0046 - L__0046)
L__0052
	mov	tiny.math.float_Pack_tmp001_, #33
	sub	tiny.math.float_Pack_tmp001_, tiny.math.float_Pack_tmp002_
	wrlong	tiny.math.float_Pack_tmp001_, fp
'     m <<= result                'msb-justify mantissa without leading 1
	add	fp, #16
	rdlong	tiny.math.float_Pack_tmp001_, fp
	sub	fp, #16
	rdlong	tiny.math.float_Pack_tmp002_, fp
	shl	tiny.math.float_Pack_tmp001_, tiny.math.float_Pack_tmp002_
	add	fp, #16
	wrlong	tiny.math.float_Pack_tmp001_, fp
'     x += 3 - result             'adjust exponent
	sub	fp, #4
	rdlong	tiny.math.float_Pack_tmp001_, fp
	sub	fp, #12
	mov	tiny.math.float_Pack_tmp002_, #3
	rdlong	tiny.math.float_Pack_tmp003_, fp
	sub	tiny.math.float_Pack_tmp002_, tiny.math.float_Pack_tmp003_
	add	tiny.math.float_Pack_tmp001_, tiny.math.float_Pack_tmp002_
	add	fp, #12
	wrlong	tiny.math.float_Pack_tmp001_, fp
' 
'     m += $00000100              'round up mantissa by 1/2 lsb
	add	fp, #4
	rdlong	tiny.math.float_Pack_tmp001_, fp
	add	tiny.math.float_Pack_tmp001_, #256
	wrlong	tiny.math.float_Pack_tmp001_, fp
'     if not m & $FFFFFF00        'if rounding overflow,
	mov	tiny.math.float_Pack_tmp002_, #0
	mov	tiny.math.float_Pack_tmp003_, tiny.math.float_Pack_tmp001_ wz
	sub	fp, #16
 if_e	neg	tiny.math.float_Pack_tmp002_, #1
	andn	tiny.math.float_Pack_tmp002_, #255 wz
 if_e	add	pc, #4*(L__0047 - ($+1))
'       x++                       '..increment exponent
	add	fp, #12
	rdlong	tiny.math.float_Pack_tmp002_, fp
	add	tiny.math.float_Pack_tmp002_, #1
	wrlong	tiny.math.float_Pack_tmp002_, fp
	sub	fp, #12
L__0047
' 
'     x := x + 127 #> -23 <# 255  'bias and limit exponent
	add	fp, #12
	rdlong	tiny.math.float_Pack_tmp001_, fp
	add	tiny.math.float_Pack_tmp001_, #127
	mins	tiny.math.float_Pack_tmp001_, imm_4294967273_
	maxs	tiny.math.float_Pack_tmp001_, #255
	wrlong	tiny.math.float_Pack_tmp001_, fp
' 
'     if x < 1                    'if exponent < 1,
	sub	fp, #12
	cmps	tiny.math.float_Pack_tmp001_, #1 wc,wz
 if_ae	add	pc, #4*(L__0049 - ($+1))
'       m := $8000_0000 +  m >> 1 '..replace leading 1
	add	fp, #16
	rdlong	tiny.math.float_Pack_tmp002_, fp
	shr	tiny.math.float_Pack_tmp002_, #1
	mov	tiny.math.float_Pack_tmp001_, imm_2147483648_
	add	tiny.math.float_Pack_tmp001_, tiny.math.float_Pack_tmp002_
	wrlong	tiny.math.float_Pack_tmp001_, fp
'       m >>= -x                  '..shift mantissa down by exponent
	sub	fp, #4
	rdlong	tiny.math.float_Pack_tmp002_, fp
	neg	tiny.math.float_Pack_tmp002_, tiny.math.float_Pack_tmp002_
	shr	tiny.math.float_Pack_tmp001_, tiny.math.float_Pack_tmp002_
	add	fp, #4
	wrlong	tiny.math.float_Pack_tmp001_, fp
	mov	tiny.math.float_Pack_tmp001_, #0
	sub	fp, #4
	wrlong	tiny.math.float_Pack_tmp001_, fp
	sub	fp, #12
L__0049
'       x~                        '..exponent is now 0
' 
'     return s << 31 | x << 23 | m >> 9 'pack result
	add	fp, #8
	rdlong	result1, fp
	shl	result1, #31
	add	fp, #4
	rdlong	tiny.math.float_Pack_tmp004_, fp
	shl	tiny.math.float_Pack_tmp004_, #23
	or	result1, tiny.math.float_Pack_tmp004_
	add	fp, #4
	rdlong	tiny.math.float_Pack_tmp005_, fp
	sub	fp, #16
	shr	tiny.math.float_Pack_tmp005_, #9
	or	result1, tiny.math.float_Pack_tmp005_
	rdlong	pc,pc
	long	@@@L__0020
L__0045
	rdlong	result1, fp
L__0020
	mov	sp, fp
	sub	sp, #4
	rdlong	fp, sp
_tiny.math.float_Pack_ret
	sub	sp, #4
	rdlong	pc, sp
hubexit
	jmp	#cogexit
objmem
	long	0[16]
stackspace
	long	0[1]
	org	COG_BSS_START
StringToFloat_tmp001_
	res	1
StringToFloat_tmp002_
	res	1
StringToFloat_tmp003_
	res	1
StringToFloat_tmp004_
	res	1
StringToFloat_tmp005_
	res	1
StringToFloat_tmp006_
	res	1
StringToFloat_tmp007_
	res	1
StringToFloat_tmp008_
	res	1
StringToFloat_tmp009_
	res	1
StringToFloat_tmp010_
	res	1
StringToFloat_tmp011_
	res	1
StringToFloat_tmp012_
	res	1
StringToFloat_tmp013_
	res	1
_StringToFloat__idx__0001
	res	1
_tmp001_
	res	1
arg1
	res	1
arg2
	res	1
arg3
	res	1
arg4
	res	1
muldiva_
	res	1
muldivb_
	res	1
tiny.math.float_FFloat_tmp001_
	res	1
tiny.math.float_FFloat_tmp002_
	res	1
tiny.math.float_FFloat_tmp003_
	res	1
tiny.math.float_FMul_tmp001_
	res	1
tiny.math.float_FMul_tmp002_
	res	1
tiny.math.float_FMul_tmp003_
	res	1
tiny.math.float_Pack_tmp001_
	res	1
tiny.math.float_Pack_tmp002_
	res	1
tiny.math.float_Pack_tmp003_
	res	1
tiny.math.float_Pack_tmp004_
	res	1
tiny.math.float_Pack_tmp005_
	res	1
tiny.math.float_Unpack_tmp001_
	res	1
tiny.math.float_Unpack_tmp002_
	res	1
tiny.math.float_Unpack_tmp003_
	res	1
LMM_RET
	res	1
LMM_FCACHE_START
	res	65
	fit	496
