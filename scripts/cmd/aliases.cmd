@echo off
:: Common DOSKEY macros, loaded via AutoRun by install.ps1 -SetupCmd
:: Save as scripts\cmd\aliases.cmd

:: Navigation
DOSKEY ..=cd ..
DOSKEY ...=cd ..\..
DOSKEY cdd=cd /d $*

:: Listing
DOSKEY ls=dir /b $*
DOSKEY ll=dir $*
DOSKEY la=dir /a $*

:: Editors and tools
DOSKEY n=notepad $*
DOSKEY e=explorer $*
DOSKEY c=code $*

:: Utilities
DOSKEY grep=rg $*
DOSKEY cat=type $*
DOSKEY findstr=findstr $*

:: Git shortcuts
DOSKEY gst=git status $*
DOSKEY gl=git log --oneline --graph --decorate $*
DOSKEY gco=git checkout $*
DOSKEY ga=git add $*
DOSKEY gc=git commit -m $*
DOSKEY gp=git push $*

:: Open current folder in Explorer
DOSKEY o.=explorer .
