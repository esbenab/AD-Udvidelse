/*******************************************************************************

PROGRAM   : group_members.sas

LAVET AF  : DKSAS30 ( Esben A Black )

DATO      : 03 August 2015
________________________________________________________________________________ 

FORR.ANSV.: Birger Larsen (JB1416)

FORMÅL: 
Målet er at lave en liste hvor der for hver gruppe listes dens medlemmer.
________________________________________________________________________________ 

LOG:                                                             
Dato:	    Hvem:                       Ændring:
03 Aug 2015	(DKSAS30) Esben A Black     Første version
 *******************************************************************************/
%let AD_SYNC_PATH=%sysget(AD_SYNC_FOLDER);
%let ACTIVE_SYMLINKS_FOLDER=%sysget(ACTIVE_SYMLINKS_FOLDER);
%let TMPDIR=%sysget(TMPDIR);
%let TMP=%sysget(TMPDIR);
libname TMP "&TMP.";
LIBNAME AD "&AD_SYNC_PATH.";
DATA WORK.interesting_groups;
	LENGTH
	group            $ 256
	symlinkname      $ 256
	path             $ 256 ;
	FORMAT
	group            $CHAR256.
	symlinkname      $CHAR256.
	path             $CHAR256. ;
	INFORMAT
	group            $CHAR256.
	symlinkname      $CHAR256.
	path             $CHAR256. ;
	INFILE "&ACTIVE_SYMLINKS_FOLDER./group_symlinks.txt"
	LRECL=256
	ENCODING="UTF-8"	
	DLM='2c'x
	MISSOVER
	DSD ;
	INPUT
	group            : $CHAR256.
	symlinkname      : $CHAR256.
	path             : $CHAR256. ;
RUN;
/*
   proc SQL noprint;
	create table unique_groups as select distinct (group) from WORK.interesting_groups;
quit;
*/
PROC SQL;
CREATE TABLE WORK.usersInGroups AS 
SELECT groups.keyid, 
	   users.memkeyid,
	   interesting_groups.symlinkname,
	   interesting_groups.path
	FROM AD.idgrps groups 
    INNER JOIN work.interesting_groups ON (groups.keyid = interesting_groups.group)
	INNER JOIN AD.grpmems users ON (groups.keyid = users.grpkeyid);
	QUIT;

	proc export data=WORK.usersInGroups
	outfile="&TMPDIR./usersInGroups.txt"
	dbms=csv
	replace;
	putnames=no;
	run;
