@echo off & setlocal enableDelayedExpansion
if not defined \e for /f %%a in ('echo prompt $E^| cmd') do set "\e=%%a"
set bxf.ver=1.0.9

if not defined subRoutineN (
	echo=BXF - Batch Expanded Functions ^| version !bxf.ver!
	echo=Compiling started at !time!
	set subRoutineN=0
)
if not exist "%~f1" (
	echo=File not found: %1
	exit /b 9009
)
set Outfile=%2
if not defined Outfile set Outfile="%~dpn1.bat"
if exist !Outfile! (
	echo=File already exists: !Outfile!
	exit /b 32
)
pushd "%~dp1"
set exitcode=0
call :main "%~f1" < "%~f1" > !Outfile! || (
	set exitcode=!errorlevel!
	del !Outfile!
)
popd
if "!subRoutineN!;!errorlevel!"=="1;0" (
	echo=Compiling finished at !time!
)
exit /b !exitcode!
:main
set /a subRoutineN+=1
set "routine[!subRoutineN!]=%~f1"
set cl=0
:main.loop
for /l %%# in (1 1 100) do for /l %%# in (1 1 100) do (
	set /a cl+=1
	set line=
	set /p line= || (
		set /a eof+=1
		if !eof! gtr 100 exit /b 0
	)
	if "!line:~0,1!"=="#" (
		if "!line:~1,9!"=="function " (
			if defined currentFunction (
				call :error Syntax error: Can't put a function into a function. Possibly missing a '#end'?
				exit /b 2
			)
			
			for /f "delims=*^!=; " %%a in ("!line:~10!") do (
				if defined f@%%a (
					call :error Syntax error: Can't re-define a function.
					exit /b 3
				)
				set "f@!prefix!%%a=!cl!"
				set "f\!prefix!%%a=%~f1"
				
				if "!line!" neq "!line:; =!" (
					set "f¤!prefix!%%a=!line:*$$=!"
					set "$=#!line:*; =!"
					set "lineLen="
					for %%$ in (4096 2048 1024 512 256 128 64 32 16) do if "!$:~%%$!" NEQ "" (
						set /a "lineLen+=%%$"
						set "$=!$:~%%$!"
					)
					set "$=!$:~1!FEDCBA9876543210"
					set /a lineLen+=0x!$:~15,1!
					
					set "$=#!line:*$$=!"
					set "endLen="
					for %%$ in (4096 2048 1024 512 256 128 64 32 16) do if "!$:~%%$!" NEQ "" (
						set /a "endLen+=%%$"
						set "$=!$:~%%$!"
					)
					set "$=!$:~1!FEDCBA9876543210"
					set /a "endLen+=0x!$:~15,1!, length=lineLen - endLen - 2"
					set "$=!line:*; =!"
					for %%b in (!length!) do set "f$!prefix!%%a=!$:~,%%b!"
				)
				set "currentFunction=!prefix!%%a"
				>&2 echo=Registered function: @!currentFunction!
			)
		) else if "!line:~1,7!"=="import " (
			set "import=!line:~8!"
			set import=!import:, =" "!
			for %%i in ("!import!") do for /f "tokens=1,2* delims=*^!	 " %%A in ("%%~i") do (
				set "importAs=%%~nA"
				set "importFrom=%%~fA"
				if "%%B"=="as" set "importAs=%%C"
				if not defined importAs (
					call :error Import error at line !cl!: "#import %%A as" Expected name.
					exit /b 6
				)
				if not exist "!importFrom!" (
					if not exist "%~dp0%%A" (
						call :error Import error at line !cl!: File not found: %%A
						exit /b 7
					) else set "importFrom=%~dp0%%A"
				)
				>&2 echo=Importing !importFrom! as !importAs!
				set "i@!importFrom!=!importAs!"
				if defined prefix set "prefix=!prefix:"=!"
				for /f "tokens=1-2* delims=." %%N in ("!cl!.!subRoutineN!.!prefix!") do (
					set "prefix=!importAs!."
					call :main "!importFrom!" < "!importFrom!" || exit /b
					set "routine[!subRoutineN!]="
					set "subRoutineN=%%O"
					set "prefix=%%P"
					set "cl=%%N"
				)
			)
			set eof=0
		) else if "!line:~0,4!"=="#end" (
			if not defined currentFunction (
				call :error Syntax error: Unexpected #end at line !cl!.
				exit /b 1
			)
			
			set "f#!currentFunction!=!cl!"
			set currentFunction=
		)
	) else if defined line (
		set eof=0
		if "!line!" neq "!line:@=!" (
			for /f "tokens=1* delims=*^!	 " %%A in ("!line!") do (
				set "expandFunction=%%A"
				if "!expandFunction!" == "!expandFunction:.=!" set "expandFunction=@!prefix!!expandFunction:~1!"
				if defined f!expandFunction! (
					if not defined currentFunction if "!expandFunction:~0,1!"=="@" call :expandFunction || exit /b
				) else if not defined currentFunction (
					if "!expandFunction:~0,1!"=="@" if /I "!expandFunction!" neq "@echo" (
						>&2 echo=[WARN] Failed to expand function ^(Possibly a forced ECHO OFF command^): !expandFunction!
					)
					echo(!line!
				) else if "!line:~0,1!" neq "	" (
					call :error Syntax error: Functions must be in a code block ^(TAB offset^)
					exit /b 18
				)
			)
		) else if not defined currentFunction (
			echo(!line!
		) else if "!line:~0,1!" neq "	" (
			call :error Syntax error: Functions must be in a code block ^(TAB offset^)
			exit /b 18
		)
	)
)
goto main.loop
:expandFunction
setlocal enableDelayedExpansion
if not defined f@!expandFunction:~1! (
	call :error "Undefined function: !expandFunction!"
	exit /b 4
)
set whitespacePrefix=
if "!line:~0,1!" == "	" for /f "tokens=1 delims=*^!@" %%a in ("!line!") do set "whitespacePrefix=%%a"


if defined f$!expandFunction:~1! (
	for /f "delims=" %%f in ("!expandFunction:~1!") do (
		set "expand=!line:*@=!"
		echo(!whitespacePrefix!!f$%%f!!expand:* =!!f¤%%f!
	)
) else (
	for /f "tokens=1*" %%a in ("!line:*@=!") do (
		setlocal disableDelayedExpansion
		for %%c in (%%b) do echo(%whitespacePrefix%set "$%%~c"
		endlocal
	)
)
for /f "delims=" %%f in ("!expandFunction:~1!") do (
	for /l %%# in (1 1 !f@%%f!) do set /p "="
	set /a "fcl=!f@%%f!+2"
	for /l %%# in (!fcl! 1 !f#%%f!) do (
		set fcl=
		set /p fcl=
		if defined fcl if "!fcl!" neq "!fcl:@=!" (
			set "line=!whitespacePrefix!!fcl:~1!"
			for /f "tokens=1* delims=*^!	 " %%A in ("!line!") do (
				set "expandFunction=%%A"
				if "!expandFunction!" == "!expandFunction:.=!" set "expandFunction=@!prefix!!expandFunction:~1!"
				if defined f!expandFunction! (
					if "!expandFunction:~0,1!"=="@" call :expandFunction || exit /b
				) else echo(!whitespacePrefix!!fcl:~1!
			)
		) else echo(!whitespacePrefix!!fcl:~1!
	)
) < "!f\%%f!"
endlocal
exit /b 0
:error
(
	echo=%\e%[38;5;1mStack trace ^(!subRoutineN!^):
	for /l %%a in (1 1 !subRoutineN!) do echo=At !routine[%%a]!
	echo=
	echo=%\e%[F  %*%\e%[0m
) >&2
exit /b
