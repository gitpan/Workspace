use ExtUtils::MakeMaker;
# Refer to lib/Extutils/MakeMaker.pm for details of 
# how to influence the contents of the Makefile that
# is written.

WriteMakefile( PREREQ_PM => { "Tk"  => '800.022' },
	       NAME => 'Tk::Shell',
	       VERSION_FROM => 'Shell.pm',
	       "dist"  => { COMPRESS  => "gzip -9f",
			    SUFFIZ    => ".gz"  } 
	       );
	      
WriteMakefile(  ABSTRACT => "Persistent Text Editor Widget",
               AUTHOR => "rkiesling\@mainmatter.com <Robert Kiesling>" ,
               PREREQ_PM => { "Tk"  => '800.022' },
	       NAME => 'Tk::Workspace',
	       VERSION_FROM => 'Workspace.pm',
	       "dist"  => { COMPRESS  => "gzip -9f",
			    SUFFIZ    => ".gz"  } 
	       );
