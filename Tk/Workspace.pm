package Tk::Workspace;
my $RCSRevKey = '$Revision: 1.41 $';
$RCSRevKey =~ /Revision: (.*?) /;
$VERSION=$1;

require Exporter;
use Carp;
use Env qw( PS1 );

use Tk qw(Ev);
use Tk::MainWindow;
use Tk::TextUndo;
use Tk::Entry;
use Tk::DialogBox;
use Tk::Dialog;
use Tk::FileSelect;
use Tk::CmdLine;

use FileHandle;
use IO::File;
use IPC::Open3;

@ISA=qw(Tk::TextUndo Exporter);
use base qw(Tk::Widget);
Construct Tk::Widget 'Workspace';

my ($tk_major_ver, $tk_minor_ver) = split /\./, $Tk::VERSION;

if( ( $tk_major_ver < '800' ) || ( $tk_minor_ver < '022' ) ) {
     die "Fatal Error: \nThis version of Workspace.pm Requires Perl/Tk 800.022.";
}

my @months = ( 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
    'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );
my @weekdays = ( 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' );

my @Workspaceobject = 
    ('#!/usr/bin/perl',
     'my $text=\'\';',
     'my $geometry=\'565x351+100+100\';',
     'my $wrap=\'word\';',
     'my $fg=\'black\';',
     'my $bg=\'white\';',
     'my $name=\'\';',
     'my $menuvisible=\'1\';',
     'my $font=\'*-courier-medium-r-*-*-12-*"\';',
     'use Tk::Workspace;', 
     '@ISA = qw(Tk::Workspace);',
     'use strict;',
     'use Tk;',
     'use FileHandle;',
     'use Env qw(HOME);',
     'my $workspace = Tk::Workspace -> new ( menubar => $menuvisible );',
     '$workspace -> name($name);',
     '$workspace -> textfont($font);',
     '$workspace -> text -> insert ( \'end\', $text );',
     '$workspace -> text -> configure( -foreground => $fg, -background => $bg, -font => $font, -insertbackground => $fg );',
     '$workspace -> text -> pack( -fill => \'both\', -expand => \'1\');',
     'bless($workspace,ref(\'Tk::Workspace\'));',
     '$workspace -> bind;',
     '$workspace -> wrap( $wrap );',
     '$workspace -> geometry( $geometry );',
     'MainLoop;' );

my $defaultbackgroundcolor="white";
my $defaultforegroundcolor="black";
my $defaulttextfont="*-courier-medium-r-*-*-12-*";
my $menufont="*-helvetica-medium-r-*-*-12-*";
my $Perlhomedirectory='.perlobjects';
my $Default=$HOME . '/' . $Perlhomedirectory . '/' . '.default';
my $SystemCopyCommand='cp';       # OS-specific file copy command.

my $clipboard;          # Internal clipboard.

# from X11 rgb.txt file
my @x11colors= ( 'snow', 'ghost white', 'white smoke', 'gainsboro',
'floral white', 'old lace', 'linen', 'antique white', 'papaya whip',
'blanched almond', 'bisque', 'peach puff', 'navajo white', 'moccasin',
'cornsilk', 'ivory', 'lemon chiffon', 'seashell', 'honeydew', 'mint cream',
'azure', 'alice blue', 'lavender', 'lavender blush', 'misty rose', 'white',
'black', 'dark slate gray', 'dim gray', 'slate gray', 'light slate gray',
'gray', 'light gray', 'midnight blue', 'navy', 'cornflower blue',
'dark slate blue', 'slate blue', 'medium slate blue', 'light slate blue',
'medium blue', 'royal blue', 'blue', 'dodger blue', 'deep sky blue',
'sky blue', 'light sky blue', 'steel blue', 'light steel blue', 'light blue',
'powder blue', 'pale turquoise', 'dark turquoise', 'medium turquoise',
'turquoise', 'cyan', 'light cyan', 'cadet blue', 'medium aquamarine',
'aquamarine', 'dark green', 'dark olive green', 'dark sea green',
'sea green', 'medium sea green', 'light sea green', 'pale green',
'spring green', 'lawn green', 'green', 'chartreuse', 'medium spring green',
'green yellow', 'lime green', 'yellow green', 'forest green', 'olive drab',
'dark khaki', 'khaki', 'pale goldenrod', 'light goldenrod yellow',
'light yellow', 'yellow', 'gold', 'light goldenrod', 'goldenrod',
'dark goldenrod', 'rosy brown', 'indian red', 'saddle brown', 'sienna',
'peru', 'burlywood', 'beige', 'wheat', 'sandy brown', 'tan', 'chocolate',
'firebrick', 'brown', 'dark salmon', 'salmon', 'light salmon', 'orange',
'dark orange', 'coral', 'light coral', 'tomato', 'orange red', 'red',
'hot pink', 'deep pink', 'pink', 'light pink', 'pale violet red', 'maroon',
'medium violet red', 'violet red', 'magenta', 'violet', 'plum', 'orchid',
'medium orchid', 'dark orchid', 'dark violet', 'blue violet', 'purple',
'medium purple', 'thistle' );

sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;
    my %args = @_;
    my $menustatus = $args{menubar};
    my $self = {
	window => new MainWindow,
	name => ((@_)?@_:'Workspace'),
	textfont => undef,
	# default is approximate width and height of 80x24 char. text widget
	width => undef,
	height => undef,
	# x and y origin are not defined until the workspace is 
	# saved again.
	x => undef,
	y => undef,
	foreground => $defaultforegroundcolor,
	background => $defaultbackgroundcolor,
	textfont => '*-courier-medium-r-*-*-12-*',
	filemenu => undef,
	editmenu => undef,
	optionsmenu => undef,
	wrapmenu => undef,
	scrollmenu => undef,
	modemenu => undef,
	helpmenu => undef,
	menubar => undef,
	popupmenu => undef,
	menubarvisible => undef,
	text => [],
	};
    bless($self, $class);
    $self -> {menubarvisible} = $menustatus;
    $self -> {window} -> {parent} = $self;
    $self -> {text} = ($self -> {window}) -> 
	    Scrolled ( 'TextUndo', -font => $defaulttextfont,
		       -background => $defaultbackgroundcolor,
		       -exportselection => 'true');
    ($self -> text) -> markGravity( 'insert', 'right' );
#   Prevents errors when trying to paste from an empty clipboard.
    ($self -> text) -> clipboardAppend( '' );
    &menus( $self );
    &set_scroll($self);
    return $self;
}



### 
### Class methods
###

sub bind {

    my $self = shift;

    ($self -> window) -> SUPER::bind('<Alt-x>', 
				    sub{$self -> ws_cut});
    ($self -> window) -> SUPER::bind('<Alt-c>', 
				    sub{$self -> ws_copy});
    ($self -> window) -> SUPER::bind('<Alt-v>', 
				    sub{$self -> ws_paste});
    ($self -> window) -> SUPER::bind('<F1>', 
				    sub{$self -> self_help});
    ($self -> window) -> SUPER::bind('<Alt-s>', 
				    sub{$self -> write_to_disk('')});
    ($self -> window) -> SUPER::bind('<Alt-q>', 
				    sub{$self -> write_to_disk('1')});
    ($self -> window) -> SUPER::bind('<Alt-u>', 
				    sub{$self -> ws_undo});
    # unbind the right mouse button.
    ($self -> window) -> bind('Tk::TextUndo', '<3>', '');

    $self -> {window} -> bind( '<ButtonPress-3>', 
			       [\&postpopupmenu, $self, Ev('x'), Ev('y') ] );
}

sub WrapMenuItems
{
 my ($w) = @_;
 my $v;
 tie $v,'Tk::Configure',$w,'-wrap';
 return  [
      [radiobutton => 'Word', -variable => \$v, -value => 'word'],
      [radiobutton => 'Character', -variable => \$v, -value => 'char'],
      [radiobutton => 'None', -variable => \$v, -value => 'none'],
	  ];
}

sub ScrollMenuItems {
    my ($self) = @_;
    return [
	 [checkbutton => 'Left', -command => 
	  sub{$self -> scrollbar('w')}, -variable => \$lscroll],
	 [checkbutton => 'Right', -command => 
	  sub{$self -> scrollbar('e')}, -variable => \$rscroll],
	 [checkbutton => 'Top', -command => 
	  sub{$self -> scrollbar('n')}, -variable => \$tscroll],
	 [checkbutton => 'Bottom', -command => 
	  sub{$self -> scrollbar('s')}, -variable => \$bscroll],
	    ];
}

###
### Instance methods.
###

sub menus {
    my $self = shift;

    $self -> {menubar} = ($self -> {window} ) -> 
	Menu ( -type => 'menubar',
	       -font => $menufont );
    $self -> {popupmenu} = ($self -> {window} ) -> 
	Menu ( -type => 'normal',
	       -tearoff => '',
	       -font => $menufont );

    $self -> {filemenu} = ($self -> {menubar}) -> Menu;
    $self -> {editmenu} = ($self -> {menubar}) -> Menu;
    $self -> {optionsmenu} = ($self -> {menubar}) -> Menu;
    $self -> {wrapmenu} = ($self -> {menubar}) -> Menu;
    $self -> {scrollmenu} = ($self -> {menubar}) -> Menu;
    $self -> {modemenu} = ($self -> {menubar}) -> Menu;
    ($self -> {helpmenu}) = ($self -> {menubar}) -> Menu;

    $self -> {menubar}  -> 
	add ('cascade',
	     -label => 'File',
	     -menu => $self -> {filemenu} );
    $self -> {menubar}  -> 
	add ('cascade',
	     -label => 'Edit',
	     -menu => $self -> {editmenu} );
    $self -> {menubar}  -> 
	add ('cascade',
	     -label => 'Options',
	     -menu => $self -> {optionsmenu} );
    $self -> {menubar} -> add ('separator');
    $self -> {menubar}  -> 
	add ('cascade',
	     -label => 'Help',
	     -menu => $self -> {helpmenu} );

    if( ( $self -> menubarvisible ) =~ m/1/ ) {
	$self -> {menubar} -> pack( -anchor => 'w', -fill => 'x' );
    }

    $self -> {popupmenu}  -> 
	add ('cascade',
	     -label => 'File',
	     -menu => $self -> {filemenu} -> 
	     clone( $self -> {popupmenu}, 'normal' ));
    $self -> {popupmenu}  -> 
	add ('cascade',
	     -label => 'Edit',
	     -menu => $self -> {editmenu} -> 
	     clone( $self -> {popupmenu}, 'normal' ) ); 

    $self -> {popupmenu}  -> 
	add ('cascade',
	     -label => 'Options',
	     -menu => $self -> {optionsmenu} -> 
	     clone( $self -> {popupmenu}, 'normal' ) ); 

    $self -> {popupmenu} -> add ('separator');
    $self -> {popupmenu}  -> 
	add ('cascade',
	     -label => 'Help',
	     -menu => $self -> {helpmenu} -> 
	     clone( $self -> {popupmenu}, 'normal' ) ); 

    $self -> {filemenu} -> add ( 'command', -label => 'Import Text...',
				 -state => 'normal',
				 -command => sub{$self -> ws_import});
    $self -> {filemenu} -> add ( 'command', -label => 'Export Text...',
				 -state => 'normal',
				 -command => sub{$self -> ws_export});
    $self -> {filemenu} -> add ('separator');
    $self -> {filemenu} -> add ( 'command', -label => 'System Command...',
				 -state => 'normal',
				 -command => sub{$self -> shell_cmd});
    $self -> {filemenu} -> add ( 'command', -label => 'Shell',
				 -state => 'normal',
				 -command => sub{$self -> ishell});
    $self -> {filemenu} -> add ('separator');
    $self -> {filemenu} -> add ( 'command', -label => 'Save...',
				 -state => 'normal',
				 -accelerator => 'Alt-S',
				 -command => sub{$self -> write_to_disk('')});
    $self -> {filemenu} -> add ( 'command', -label => 'Exit...',
				 -state => 'normal',
				 -accelerator => 'Alt-Q',
				 -command => sub{$self -> write_to_disk('1')});
    ($self -> { filemenu }) -> configure( -font => $menufont );
    $self -> {editmenu} -> add ( 'command', -label => 'Undo',
				 -state => 'normal',
				 -accelerator => 'Alt-U',
				 -font => $menufont,
				 -command => sub{$self -> ws_undo});
    $self -> {editmenu} -> add ('separator');
    $self -> {editmenu} -> add ( 'command', -label => 'Cut',
				 -state => 'normal',
				 -accelerator => 'Alt-X',
				 -font => $menufont,
				 -command => sub{$self -> ws_cut});
    $self -> {editmenu} -> add ( 'command', -label => 'Copy',
				 -accelerator => 'Alt-C',
				 -state => 'normal',
				 -font => $menufont,
				 -command => sub{$self -> ws_copy});
    $self -> {editmenu} -> add ( 'command', -label => 'Paste',
				 -accelerator => 'Alt-V',
				 -state => 'normal',
				 -font => $menufont,
				 -command => sub{$self -> ws_paste});
    $self -> {editmenu} -> add ('separator');
    $self -> {editmenu} -> add ( 'command', -label => 'Evaluate Selection',
				 -state => 'normal',
				 -command => sub{$self -> evalselection()});
    $self -> {editmenu} -> add ('separator');
    my $items = ($self -> {text}) -> SUPER::SearchMenuItems();
    ($self -> {editmenu}) -> AddItems ( @$items );
    ($self -> { editmenu }) -> configure( -font => $menufont );
    $self -> {editmenu} -> add ('separator');
    $self -> {editmenu} -> add ( 'command', -label => 'Goto Line...',
				 -state => 'normal',
				 -font => $menufont,
		 -command => sub{&goto_line($self -> {text})});

    $self -> {editmenu} -> add ( 'command', -label => 'Which Line?',
				 -state => 'normal',
				 -font => $menufont,
	 -command => sub{&what_line($self -> {text})});

    ($self -> { optionsmenu }) -> configure( -font => $menufont );
    $self -> {optionsmenu} -> add ( 'cascade',
				    -label => 'Word Wrap',
				    -menu => $self -> {wrapmenu} );
    $items = &WrapMenuItems($self -> {text});
    $self -> {wrapmenu} -> AddItems( @$items );
    $self -> {optionsmenu} -> add ( 'cascade',
				    -label => 'Scroll Bars',
				    -menu => $self -> {scrollmenu} );
    $items = &ScrollMenuItems($self);
    $self -> {scrollmenu} -> AddItems( @$items );
    $self 
	-> {optionsmenu} -> 
	    add ( 'command',
		  -label => 'Show/Hide Menubar',
		  -command => [\&togglemenubar, $self ] );
    $self -> {optionsmenu} -> add ('separator');
    $self -> {optionsmenu} -> add ( 'command', -label => 
				    'Foreground Color...',
				 -state => 'normal',
				 -font => $menufont,
	 -command => [\&ws_setcolor, $self, 'foreground']);
    $self -> {optionsmenu} -> add ( 'command', -label => 
				    'Background Color...',
				 -state => 'normal',
				 -font => $menufont,
	 -command => [\&ws_setcolor, $self, 'background']);
    $self -> {optionsmenu} -> add ('separator');
    $self -> {optionsmenu} -> add ( 'command', -label => 'Text Font...',
				 -state => 'normal',
				 -font => $menufont,
	 -command => [\&ws_font, $self]);

    $self -> {helpmenu} -> add ( 'command', -label => 'About...',
				 -state => 'normal',
				 -font => $menufont,
				 -command => sub{$self -> about});
    $self -> {helpmenu} -> add ( 'command', -label => 'Help...',
				 -state => 'normal',
				 -font => $menufont,
				 -accelerator => "F1",
				 -command => sub{self_help(__FILE__)});
}

sub window {
    my $self = shift;
    if (@_) { $self -> {window} = shift }
    return $self -> {window}
}

sub text {
    my $self = shift;
    if (@_) { $self -> {text} = shift }
    return $self -> {text}
}

sub name {
    my $self = shift;
    if (@_) { $self -> {name} = shift }
    return $self -> {name}
}

sub textfont {
    my $self = shift;
    if (@_) { $self -> {textfont} = shift }
    return $self -> {textfont}
}

sub menubar {
    my $self = shift;
    if (@_) { $self -> {menubar} = shift }
    return $self -> {menubar}
}

sub menubarvisible {
    my $self = shift;
    if (@_) { $self -> {menubarvisible} = shift }
    return $self -> {menubarvisible}
}

sub popupmenu {
    my $self = shift;
    if (@_) { $self -> {popupmenu} = shift }
    return $self -> {popupmenu}
}

sub filemenu {
    my $self = shift;
    if (@_) { $self -> {filemenu} = shift }
    return $self -> {filemenu};
}

sub wrap {
    my $self = shift;
    my $w = $self -> {wrapmenu};
    if( @_) { 
	my $m = shift; 
	if ( $m =~ m/word/ ) { $w -> invoke( 1 ) };
	if ( $m =~ m/char/ ) { $w -> invoke( 2 ) };
	if ( $m =~ m/none/ ) { $w -> invoke( 3 ) };
    }
    return ($self -> {text}) -> cget('-wrap');
}

sub parent_ws {
# We say parent_ws because MainWindows' parents are not recognized 
# by default.
    my $self = shift;
    if (@_) { $self -> {parent_ws} = shift }
    return $self -> {parent_ws}
}

sub editmenu {
    my $self = shift;
    if (@_) { $self -> {editmenu} = shift }
    return $self -> {editmenu}
}

sub helpmenu {
    my $self = shift;
    if (@_) { $self -> {helpmenu} = shift }
    return $self -> {helpmenu}
}

sub optionsmenu {
    my $self = shift;
    if (@_) { $self -> {optionsmenu} = shift }
    return $self -> {optionsmenu}
}

sub width {
    my $self = shift;
    if (@_) { $self -> {width} = shift }
    return $self -> {width}
}

sub height {
    my $self = shift;
    if (@_) { $self -> {height} = shift }
    return $self -> {height}
}

# show or hide menubar
sub togglemenubar {
    my $self = shift;

    $self -> {text} -> packForget;
    $self -> {menubar} -> packForget;
    if( ($self -> {menubarvisible}) =~ m/1/ ) {
	$self -> {menubarvisible} = '';
    } else {
	$self -> {menubar} -> pack( -side => 'top', -anchor => 'w', 
				  -fill => 'x' );
	$self -> {menubarvisible} = '1';
    }
    $self -> {text} -> pack( -side => 'top', -fill => 'both', -expand => '1' );
    return $self -> {menubarvisible}
}

sub x {
    my $self = shift;
    if (@_) { $self -> {x} = shift }
    return $self -> {x}
}

sub y {
    my $self = shift;
    if (@_) { $self -> {y} = shift }
    return $self -> {y}
}

sub open {
    my ($name) = @_;

    my @command_line = ( "\./" . $name . ' &');
    system( @command_line );
}

sub geometry {
    my $self = shift;
    my $g = shift;

    $g =~ m/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/;
    $self -> width($1); $self -> height($2); $self -> x($3); 
    $self -> y($4);

    $self -> window -> geometry( $g );
}

sub postpopupmenu {
    my $w = shift;
    my $self = shift;
    my $x = shift;
    my $y = shift;
    my $g = ($self -> window) -> geometry;
    $g =~ m/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/;
    $self -> width($1); $self -> height($2); $self -> x($3); 
    $self -> y($4);
    ($self -> popupmenu) -> post( $self -> x + $x, $self -> y + $y );
}

#
# These two subroutines are adapted from Text.pm of Perl/Tk 800.022
#
sub what_line
{
 my ($w)=@_;
 my ($line,$col) = split(/\./,$w->index('insert'));
 $w->messageBox(-type => 'Ok', -title => "What Line Number",
                -message => "The cursor is on line $line (column is $col)");
}

sub goto_line
{
 my ($w)=@_;
 my $popup = $w->{'GOTO_LINE_NUMBER_POPUP'};

 unless (defined($w->{'LAST_GOTO_LINE'}))
  {
   my ($line,$col) =  split(/\./, $w->index('insert'));
   $w->{'LAST_GOTO_LINE'} = $line;
  }

 ## if anything is selected when bring up the pop-up, put it in entry window.	
 my $selected;
 eval { $selected = $w->SelectionGet(-selection => "PRIMARY"); };
 unless ($@)
  {
   if (defined($selected) and length($selected))
    {
     unless ($selected =~ /\D/)
      {
       $w->{'LAST_GOTO_LINE'} = $selected;
      }
    }
  }
 unless (defined($popup))
  {
   require Tk::DialogBox;
   $popup = $w->DialogBox(-buttons => [qw[Ok Cancel]],-title => "Goto Line Number", -popover => $w,
                          -command => sub { $w->GotoLineNumber($w->{'LAST_GOTO_LINE'}) if $_[0] eq 'Ok'});
   $w->{'GOTO_LINE_NUMBER_POPUP'}=$popup;
   $popup->resizable('no','no');
   my $frame = $popup->Frame->pack(-fill => 'x');
   $frame->Label(text=>'Enter line number: ')->pack(-side => 'left');
   my $entry = $frame->Entry(-background=>'white',width=>25,
                             -textvariable => \$w->{'LAST_GOTO_LINE'})->pack(-side =>'left',-fill => 'x');
   $popup->Advertise(entry => $entry);
  }
 $popup->Popup;
 $popup->Subwidget('entry')->focus;
 $popup->Wait;
}


sub scrollbar {
    my $self = shift;
    if (@_) { 
	my ($p) = @_;
	if (($p=~m/w/)&&($lscroll=='1')){
	    $self->{scroll}.='w';
	    $self->{scroll} =~ s/e//; $rscroll = '0';
	} 
	elsif (($p=~m/e/)&&($rscroll=='1')) {
	    $self->{scroll}.='e';
	    $self->{scroll} =~ s/w//; $lscroll = '0';
	} 
	elsif (($p=~m/n/)&&($tscroll=='1')) {
	    $self->{scroll} = 'n' . $self -> {scroll};
	    $self->{scroll} =~ s/s//;  $bscroll = '0';
	} 
	elsif(($p=~m/s/)&&($bscroll=='1')) {
	    $self->{scroll} = 's' . $self -> {scroll};
	    $self->{scroll} =~ s/n//;  $tscroll = '0';
	}
	else { 
	    $self -> {scroll} =~ s/$p//;
	}
	&set_scroll( $self );
	return $self -> {scroll};
    }
}

sub set_scroll {
    my ($self) = @_;
    $self -> {text} -> configure( -scrollbars => $self -> {scroll} );
    $self -> {text} -> pack( -expand => '1', -fill => 'both' );
}

sub ws_font {
    my ($self) = @_;
    my @systemfonts;
    my $dialog;
    my $listframe;
    my $buttonframe;
    my $acceptbutton;
    my $applybutton;
    my $cancelbutton;
    my $f;

    $dialog = ($self -> window) -> 
	    Toplevel( -title => 'Select Font' );
    $listframe = $dialog -> Frame( -container => 'no');
    $buttonframe = $dialog -> Frame( -container => 'no');
    $listframe -> pack;
    $buttonframe -> pack;
    open FONTLIST, 'xlsfonts|' or printf STDERR 
	"Could not get system fonts using xlsfonts.\n";
    while ( <FONTLIST> ) {
	@systemfonts = map {split /^/m; } <FONTLIST>; 
    }
    close FONTLIST;
    $list = $listframe -> 
	Scrolled( 'Listbox', -height => 20, -width => 55,
		 -selectmode => 'single',
		 -scrollbars => 'se' );
    foreach $f ( @systemfonts ) { $list -> insert( 'end', $f ); }
    $list -> pack( -anchor => 'w', -fill => 'x' );
    $acceptbutton = $buttonframe 
	-> Button( -text => 'Accept',
		   -command => [\&fontdialogaccept, $dialog, $list, $self]) 
	    -> pack( -side => 'left' );
    $applybutton = $buttonframe 
	-> Button( -text => 'Apply',
		   -command => [\&fontdialogapply, $dialog, $list, $self]) 
	    -> pack( -side => 'left' );
    $cancelbutton = $buttonframe 
	-> Button( -text => 'Cancel',
		   -command => [\&fontdialogclose, $dialog]) 
	    -> pack( -side => 'left');
}

sub fontdialogaccept {
    my ($d, $list, $self) = @_;
    &fontdialogapply( $d, $list, $self );
    &fontdialogclose( $d );
}

sub fontdialogapply {
    my ($d, $list, $self) = @_;
    my $f;
    my $newheight;
    my $newwidth;
    my $oldgeometry;
    my $x;
    my $y;
    $f = $list -> get( $list -> curselection );
    ($self -> text) -> configure( -font => $f );
    $self -> textfont( $f );
    $oldgeometry = ($self -> window) -> geometry();
    $oldgeometry =~ m/.+x.+\+(.+)\+(.+)/;
    $x = $1; $y = $2;
    $newwidth = ($self -> text) -> reqwidth;
    $newheight = ($self -> text) -> reqheight;
    ($self -> window) -> geometry($newwidth . 'x' . $newheight .
				    '+' . $x . '+' . $y );
}

sub fontdialogclose {
    my ($d) = @_;
    $d -> DESTROY;
}

sub ws_setcolor {
    my ($self, $element) = @_;
    my $list;
    my $dialog;
    my $listframe;
    my $buttonframe;
    my $acceptbutton;
    my $applybutton;
    my $cancelbutton;
    my $c;
    my $title;

    if ( $element =~ m/foreground/ ) {
	$title = 'Set Foreground Color';
    } elsif ($element =~ m/background/) {
	$title = 'Set Background Color';
    }
	$dialog = ($self -> window) -> 
	    Toplevel( -title => $title );
    $listframe = $dialog -> Frame( -container => 'no');
    $buttonframe = $dialog -> Frame( -container => 'no');
    $listframe -> pack;
    $buttonframe -> pack;

    $list = $listframe -> 
	Scrolled( 'Listbox', -height => 20, -width => 25,
		 -selectmode => 'single',
		 -scrollbars => 'e');
    foreach $c ( @x11colors ) {	$list -> insert( 'end', $c ); }
    $list -> pack( -anchor => 'w' );

    $acceptbutton = $buttonframe 
	-> Button( -text => 'Accept',
		   -command => [\&colordialogaccept, $dialog, $list, $self,
				$element]) 
	    -> pack( -side => 'left' );
    $applybutton = $buttonframe 
	-> Button( -text => 'Apply',
		   -command => [\&colordialogapply, $dialog, $list, $self,
				$element]) 
	    -> pack( -side => 'left' );
    $cancelbutton = $buttonframe 
	-> Button( -text => 'Cancel',
		   -command => [\&colordialogclose, $dialog]) 
	    -> pack( -side => 'left');
}

sub colordialogaccept {
    my ($d, $list, $self, $element) = @_;
    &colordialogapply( $d, $list, $self, $element );
    &colordialogclose( $d );
}

sub colordialogapply {
    my ($d, $list, $self, $element) = @_;
    my $c;
    $c = $list -> get( $list -> curselection );
    if ( $element =~ m/foreground/ ) {
	($self -> text) -> configure( -foreground => $c,
				      -insertbackground => $c );
    } elsif ( $element =~ m/background/ ) {
	($self -> text) -> configure( -background => $c );
    }
}

sub colordialogclose {
    my ($d) = @_;
    $d -> DESTROY;
}

sub write_to_disk {
    my $self = shift;
    my $quit = shift;   # Close workspace if true
    my $dir = $HOME . '/' . $Perlhomedirectory;
    my $workspacename = $self -> name;
    my $height = $self -> height;
    my $width = $self -> width;
    my $geometry;
    my $workspacepath = $workspacename;
    my $tmppath = $workspacepath . ".tmp";
    my $contents;
    my $object;
    my $x;
    my $y;
    my $fg;
    my $bg;
    my $f;
    my $resp;
    my $wrap;
    my $mb;

    if( $quit ) { 
	if ( ( $resp = &close_dialog($self) ) =~ m/Cancel/) { 
	    return;
	} elsif ( $resp !~ m/Yes/ ) {
	    goto EXIT;
	}
    }

    open FILE, ">>" . $tmppath;
    $contents = ($self -> text) -> get( '1.0', end );
    printf FILE '#!/usr/bin/perl' . "\n";

    $geometry= ($self -> window) -> geometry;
    $geometry =~ m/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/;
    $width = $1; $height = $2; $x = $3; $y = $4;

    $wrap = $self -> wrap;
    $mb = $self -> menubarvisible;

    $fg = ($self -> text) -> cget('-foreground');
    $bg = ($self -> text) -> cget('-background');
    $f = $self -> textfont;

    # concatenate text.
    printf FILE 'my $text = <<\'end-of-text\';' . "\n";
    printf FILE $contents;
    printf FILE "end-of-text\n";

    # This re-creates on the default workspace object, except
    # the first line, the name, height and width, x and y orgs,
    # foreground and background colors,
    # and the initial empty text.;
    my @tmpobject = @Workspaceobject;
    grep { s/name\=\'\'/name=\'$workspacename\'/ } @tmpobject;
    grep { s/geometry\=\'.*\'/geometry=\'$geometry\'/ } @tmpobject;
    grep { s/wrap\=\'.*\'/wrap=\'$wrap\'/ } @tmpobject;
    grep { s/fg\=\'.*\'/fg=\'$fg\'/ } @tmpobject;
    grep { s/bg\=\'.*\'/bg=\'$bg\'/ } @tmpobject;
    grep { s/font\=\'.*\'/font=\'$f\'/ } @tmpobject;
    grep { s/menuvisible\=\'.*\'/menuvisible=\'$mb\'/ } @tmpobject;
    grep { s/#!\/usr\/bin\/perl// } @tmpobject;
	   grep { s/my \$text=\'\'\;// } @tmpobject;
	   foreach $line ( @tmpobject ) { printf FILE $line . "\n"; };
	   close FILE;
	   my @remove_old = ( 'mv', $tmppath, $workspacepath );
	   system( @remove_old );
	   chmod 0755, $workspacepath;

EXIT:	   if ( $quit ) { exit 0; }
}

# Create a new Workspace executable if one doesn't exist.
sub create {
    my ($workspacename) = ((@_)?@_:'Workspace');
    my $Source;
    my $directory = ''; # Where are we.

    # Make sure a workspace executable of the same basename
    # doesn't exist already.  If it does, make the old workspace
    # a backup.  
    if ( -e $workspacename ) {
	rename $workspacename, $workspacename . '.bak';
    }

    # try again.
    #Name the workspace...
    my @tmpobject = @Workspaceobject;
    grep { s/name\=\'\'/name\=\'$workspacename\'/ } @tmpobject;

    open FILE, ">" . $workspacename 
	or die "Can't open Workspace " . $workspacename;
    # This creates on the default workspace object.

    foreach $line ( @tmpobject ) { printf FILE $line . "\n"; }
    close FILE;
    chmod 0755, $workspacename;
    utime time, time, ($workspacename);
    return( $workspacename );
}

sub ws_copy {
    my $self = shift;
    my $selection;
    if ( ! (($self -> {text}) -> tagRanges('sel')) ) { return; }
    # per clipboard.txt, this asserts workspace text widget's 
    # ownership of X display clipboard, and clears it.
    ($self -> {text}) -> clipboardClear;
    $selection = ($self -> {text}) 
	-> SelectionGet(-selection => 'PRIMARY',
			-type => 'STRING' );
    # Appends PRIMARY selection to X display clipboard.
    ($self -> {text}) -> clipboardAppend($selection);
    $clipboard = $selection;   # our  clipboard, not X's.
    return $selection;
}

sub ws_cut {
    my $self = shift;
    my $selection;
    if ( ! (($self -> {text}) -> tagRanges('sel')) ) { return; }
    # per clipboard.txt, this asserts workspace text widget's 
    # ownership of X display clipboard, and clears it.
    ($self -> {text}) -> clipboardClear;
    $selection = ($self -> {text}) 
	-> SelectionGet(-selection => 'PRIMARY',
			-type => 'STRING' );
    # Appends PRIMARY selection to X display clipboard.
    ($self -> {text}) -> clipboardAppend($selection);
    ($self ->{text}) -> 
	delete(($self -> {text}) -> tagRanges('sel'));
    $clipboard = $selection;   # our  clipboard, not X's.
    return $selection;
}

sub ws_paste {
    my $self = shift;
    my $selection;
    my $point;
    # Don't use CLIPBOARD because of a bug? in PerlTk...
    #
    # Checks PRIMARY selection, then X display clipboard, 
    # and returns if neither is defined.
#    ($self -> {text}) -> 
#	selectionOwn(-selection => 'CLIPBOARD');
#    if ( ! (($self -> {text}) -> tagRanges('sel')) 
#	 or (($selection =  ($self -> {text}) 
#	-> SelectionGet(-selection => 'PRIMARY',
#			-type => 'STRING')) == '') ) {
#	return; 
#    }
#    if ($self -> {text} -> tagRanges('sel')) {
#	$selection = ($self -> {text}) 
#	    -> SelectionGet(-selection => 'PRIMARY',
#			    -type => 'STRING');
#    } else {
#	$selection = $clipboard;
#    }
    $selection = ($self -> {text}) -> clipboardGet;
    $point = ($self -> {text}) -> index("insert");
    ($self -> {text}) -> insert( $point,
				      $selection);
    return $selection;
}

sub ws_undo {
    my $self = shift;
    my $undo;
    $undo = ($self -> {text}) -> undo;
    return $self
}

sub evalselection {
    my $self = shift;
    my $s;
    my $result;
    $s = ($self -> {text})
	-> SelectionGet( -selection => 'PRIMARY',
			 -type => 'STRING' );
    $result = eval $s;
    ($self -> {text}) -> 
	insert( ( ( $self -> {text} ) -> 
		  tagNextrange( 'sel', '1.0', 'end' ))[1], $result );
}

sub about {
    my $self = shift;
    my $aboutdialog;
    my $title_text;
    my $version_text;
    my $name_text;
    my $mod_time;
    my $line_space;  # blank label as separator.
    my @filestats = { $device,
		    $inode,
		    $nlink,
		    $uid,
		    $gid,
		    $raw_device,
		    $size,
		    $atime,
		    $mtime,
		    $ctime,
		    $blksize,
		    $blocks };
    
    @filestats = stat ($self -> {name});

    $aboutdialog = 
	($self -> {window}) -> 
	    DialogBox( -buttons => ["Ok"],
		       -title => 'About' );
    $title_text = $aboutdialog -> add ('Label');
    $version_text = $aboutdialog -> add ('Label');
    $name_text = $aboutdialog -> add ('Label');
    $mod_time = $aboutdialog -> add ('Label');
    $line_space = $aboutdialog -> add ('Label');

    $title_text -> configure ( -font => $menufont,
			       -text => 
	       'Workspace.pm by rkiesling@mainmatter.com <Robert Kiesling>' );
    $version_text -> configure ( -font => $menufont,
				 -text => "Version:  $VERSION");
    $name_text -> configure ( -font => $menufont,
                              -text => "\'" . $self -> {name} . "\'" );
    $mod_time -> configure ( -font => $menufont,
                             -text => 'Last File Modification: ' . 
                             localtime($filestats[9])  );
    $line_space -> configure ( -font =>$menufont,
                               -text => '');

    $name_text -> pack;
    $mod_time -> pack;
    $line_space -> pack;
    $title_text -> pack;
    $version_text -> pack;
    $aboutdialog -> Show;
}

sub ws_import {

    my $self = shift;
    my $import;
    my $filedialog;
    my $filename = ''; 
    my $l;
    my $nofiledialog;
    
    $filedialog = ($self -> {window}) 
	-> FileSelect ( -directory => '.');
    $filename = $filedialog -> Show;

    if ( $filename ) {
	open IMPORT, "< $filename" or &filenotfound($self);
    }

    while ( $l = <IMPORT> ) {
	($self -> {text}) -> insert ( 'insert', $l );
    }
    ($self -> {text}) -> pack;
    close IMPORT;
}

sub ws_export {
    my $self = shift;
    my $filedialog;
    my $filename;
    my $filename;
    my $fh = new IO::File;


START:    $filedialog = ($self -> {window})
	-> FileSelect ( -directory => '.' );
    $filename = $filedialog -> Show;

    $fh -> open( "+> $filename" ) or &filenotfound( $self );

    print $fh ($self -> {text}) -> get( '1.0', 'end' );

    close $fh;
}

sub close_dialog {
    my $self = shift;
    my $dialog;
    my $response;
    my $notice = "Save this workspace\nbefore closing?";

    $dialog =  ( $self -> {window} )
	-> Dialog( -title => 'Close Workspace',
		   -text => $notice, -bitmap => 'question',
		   -buttons => [qw/Yes No Cancel/]);
    return $response = $dialog -> Show;
}

sub filenotfound {

    my $self = shift;

    my $nofiledialog = 
	($self -> {window}) ->
		DialogBox( -buttons => ["OK"],
			   -title => 'File Error' );
    my $filenotfound = $nofiledialog -> add ( 'Label'); 
    $filenotfound -> configure ( -font => $menufont,
			   -text => 'Could not open file.');
    $filenotfound -> pack;
    $nofiledialog -> Show;
}

sub ishell {
    my $self = shift;
    my $p = &prompt( $ENV{'PS1'} );

    ($self -> window) -> bind( '<KeyPress-Return>', 
			       sub{shell_client( $self )});
    &insert_output( $self, "\n" );
    &insert_output( $self, $p ); 
}

# external programs that the shell executes
sub shell_client {
    my $self = shift;
    my $cmdline; my $cmd;
    my $p = &prompt( $ENV{'PS1'} );
    my $o; my $output = '';

    # Need to open and then close each I/O channel
    # immediately to avoid potential deadlocks.

    $shpid = open3( *IN, *OUT, *ERR, "bash" );

    my $startofprompt = 
	($self -> text) -> 
	    search( -backwards, -exact, $p, 
		    $self -> text -> index( 'insert' ) );
    $cmdline = ($self -> text) -> get( $startofprompt, 'insert' );

    $cmd = substr $cmdline, length $p ;
    chop $cmd;
    print IN $cmd;
    close ( IN );

    foreach $o (<OUT>) { $output .= $o };
    close( OUT );
    foreach $o (<ERR>) { $output .= $o };
    close( ERR );

    &insert_output( $self, $output );

    if( $cmd =~ /exit/ ) {
	($self -> window) -> bind( '<KeyPress-Return>', '' );
	return;
    } elsif ( ( $cmd =~ /cd/ ) || ( $cmd =~ /chdir/ ) ) {
	$cmd =~ s/(cd )|(chdir )//;
	chdir $cmd;
    }
    $p = &prompt( $ENV{'PS1'} );
    &insert_output( $self, $p ); 
}

# subset of bash prompt syntax only for now.  
sub prompt {
    my ($s) = @_;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = 
	localtime;
    my $calyear = $year + 1900;
    my $mname = $months[$mon];
    my $day = $weekdays[$wday];

    if( $s =~ m/\\/ ) {
	if ( $s =~ m/\\[hH]/ ) {
	    my $hme = `hostname`;
	    chop $hme;
	    $s =~ s/\\h/$hme/;
	}
# eat a possible ANSI sequence.
	if ( $s =~ m/\\e/ ) { 
	    $s =~ s/\\e]*[^;]*\;*//;
        }
        if ( $s =~ m/\\t/ ) {
	    $s =~ s/\\t/$hour:$min:$sec/;
	}
        if ( $s =~ m/\\T/ ) {
	    my $thour = (($hour == 12)?12:($hour - 12));
	    $s =~ s/\\T/$thour:$min:$sec/;
	}
        if ( $s =~ m/\\@/ ) {
	    my $thour = (($hour == 12)?12:($hour - 12));
	    my $merid = ((($hour<12||$hour==24))?'am':'pm');
		$s =~ s/\\@/$thour:$min$merid/;
	}
        if ( $s =~ m/\[wW]/ ) {
        }
             my $dir = `pwd`;
             chop $dir;
             $s =~ s/\\W/$dir/;
        }
        if ( $s =~ m/\\d/ ) {
             $s =~ s/\\d/$day $mname $mday/;
        }
# eat an octal sequence,
$s =~ s/\\[0-9][0-9][0-9]//; 
# gobble newlines,
$s =~ s/\n//s;
# and other prompt variables not yet implemented
$s =~ s/\\(u|v|V|a|!|\$|\\|\[)//g;
# doesn't work with an empty prompt, so...
if ( ! $s ) { $s = "# "; }
return $s;
}

# internal shell commands and 
sub shell_internal {
    my $self = shift;
}

sub shell_cmd {
    my $self = shift;
    local $cmd; local $output;
    local $cmdentry;

    $cmddialog = ($self -> window) -> Dialog( -title => 'Shell Command',
					      -buttons => ["Cancel"]);
    $cmdentry = $cmddialog -> add( 'Entry', -width => 30 ) -> pack;
    $cmddialog -> Show;
    $cmd = $cmdentry -> get;
    $output = `$cmd`;
    &insert_output( $self, $output );
    $cmddialog -> destroy;
}


sub insert_output {
    my $self = shift; 
    my $output = shift;

    ($self -> text) -> insert( $self -> text -> index( "insert" ), $output );
    ($self -> text) -> see( $self -> text -> index( "insert" ) );
    $self -> window -> update; 
    $self -> text -> update;
}

sub my_directory {
    open PATHNAME, "pwd |";
    read PATHNAME, $directory, 512;
    close PATHNAME;
}

sub self_help {
    my ($appfilename) = @_;
    my $help_text;
    my $helpwindow;
    my $textwidget;

    open( HELP, ("pod2text < $appfilename |") ) or $help_text = 
"Unable to process help text for $appfilename."; 
    while (<HELP>) {
	$help_text .= $_;
    }
    close( HELP );

    $helpwindow = new MainWindow( -title => "$appfilename Help" );
    my $textframe = $helpwindow -> Frame( -container => 0, 
					  -borderwidth => 1 ) -> pack;
    my $buttonframe = $helpwindow -> Frame( -container => 0, 
					  -borderwidth => 1 ) -> pack;
    $textwidget = $textframe  
	-> Scrolled( 'Text', 
		     -font => $defaulttextfont,
		     -scrollbars => 'e' ) -> pack( -fill => 'both',
						   -expand => 1 );
    $textwidget -> insert( 'end', $help_text );

    $buttonframe -> Button( -text => 'Close',
			    -font => $menufont,
			    -command => sub{$helpwindow -> DESTROY} ) ->
				pack;
}


1;
__END__

=head1 NAME

Workspace.pm -- Library to create and use a persistent, embedded Perl
            workspace (file browser, shell, editor) script using
            Perl/Tk.

=head1 SYNOPSIS

   # Create a workspace from the shell prompt:

     #mkws "workspace"

   # Open an existing workspace:

     #./workspace &

   # In a Perl script:

      use Tk::Workspace;

      Tk::Workspace::open(Tk::Workspace::create("workspace"));

=head1 DESCRIPTION

Workspace uses the Tk::TextUndo widget to create an embedded Perl
text editor.  The resulting file can be run as a standalone
program.  

=head1 MENU FUNCTIONS

A workspace contains a menu bar with File, Edit, Options, and Help
menus.  

The menus also pop up by pressing the right mouse button (Button-3)
over the text area, whether the menu bar is visible or not.

The menu functions are provided by the Tk::Workspace, Tk::TextUndo,
Tk::Text, and Tk::Widget modules.

=head2 File Menu

Import Text -- Insert the contents of a selected text file at the
insertion point.

Export Text -- Write the contents of the workspace to a text file.

System Command -- Prompts for the name of a command to be executed
by the shell, /bin/sh.  The output is inserted into the workspace.

For example, to insert a manual page into the workspace, enter:

   man <programname> | colcrt - | col -b

Shell -- Starts an interactive shell.  The prompt is the PS1 prompt of
the environment where the workspace was started.  At present the
workspace shell recognizes only a subset of the bash prompt variables,
and does not implement command history or setting of environment
variables in the subshell.  Refer to the bash(1) manual page for
further information.

Typing 'exit' leaves the shell and returns the workspace to normal
text editing mode.

Save -- Save the workspace to disk.

Quit -- Close the workspace window, optionally saving to disk.

=head2 Edit Menu 

Undo -- Reverse the next previous change to the text.

Cut -- Delete the selected text and place it on the X clipboard.

Copy -- Copy the selected text to the X clipboard.

Paste -- Insert text from the X clipboard at the insertion point.

Evaluate Selection -- Interpret the selected text as Perl code.

Find -- Search for specified text, and specify search options.  Marks
text for later replacement (see below).

Find Next -- Find next match of search text.

Previous -- Find previous match of search text.

Replace -- Replace marked search text with text from the replacement
entry.

Goto Line -- Go to the line entered by the user.

Which Line -- Report the line and column position of the 
insertion point.

=head2 Options Menu

Wrap -- Select how the text should wrap at the right margin.

Scroll Bars -- Select from scroll bars at right or left, top or bottom of
the text area.

Show/Hide Menubar -- Toggle whether the menubar is visible.  A popup
version of the menus is always available by pressing the right
mouse button (Button 3) over the text area.

Foreground Color -- Select foreground and insertion cursor 
color from list of system colors.

Background Color -- Select text window background color from
list of system colors.

Text Font -- Select text font from list of system fonts.

=head2 Help Menu

About -- Report name of workspace and modification time, and
version of Workspace.pm library.

Help -- Display the Workspace.pm POD documentation in a text window
formatted by pod2text.

=head1 KEY BINDINGS

For further information, please refer to the Tk::Text 
and Tk::bind man pages.

    Alt-Q                 Quit, Optionally Saving Text
    Alt-S                 Save Workspace to Disk
    Alt-U                 Undo
    Alt-X                 Copy Selection to Clipboard and Delete
    Alt-C                 Copy Selection to Clipboard
    Alt-V                 Insert Clipboard Contents at Cursor
    
    Right, Ctrl-F         Forward Character
    Left, Ctrl-B          Backward Character
    Up, Ctrl-P            Up One Line
    Down, Ctrl-N          Down One Line
    Shift-Right           Forward Character Extend Selection
    Shift-Left            Backward Character Extend Selection
    Shift-Up              Up One Line, Extend Selection
    Shift-Down            Down One Line, Extend Selection
    Ctrl-Right, Meta-F    Forward Word
    Ctrl-Left, Meta-B     Backward Word
    Ctrl-Up               Up One Paragraph
    Ctrl-Down             Down One Paragraph
    PgUp                  Scroll View Up One Screen
    PgDn                  Scroll View Down One Screen
    Ctrl-PgUp             Scroll View Right
    Ctrl-PgDn             Scroll View Left
    Home, Ctrl-A          Beginning of Line
    End, Ctrl-E           End of Line
    Ctrl-Home, Meta-<     Beginning of Text
    Ctrl-End, Meta->      End of Text
    Ctrl-/                Select All
    Ctrl-\                Clear Selection
    F16, Copy, Meta-W     Copy Selection to Clipboard
    F20, Cut, Ctrl-W      Copy Selection to Clipboard and Delete
    F18, Paste, Ctrl-Y    Paste Clipboard Text at Insertion Point
    Delete, Ctrl-D        Delete Character to Right, or Selection
    Backspace, Ctrl-H     Delete Character to Left, or Selection
    Meta-D                Delete Word to Right
    Meta-Backspace, Meta-Delete
                          Delete Word to Left
    Ctrl-K                Delete from Cursor to End of Line
    Ctrl-O                Open a Blank Line
    Ctrl-X                Clear Selection
    Ctrl-T                Reverse Order of Characters on Either Side
                          of the Cursor
    

    Mouse Button 1:
    Single Click: Set Insertion Cursor at Mouse Pointer
    Double Click: Select Word Under the Mouse Pointer and Position 
    Cursor at the Beginning of the Word
    Triple Click: Select Line Under the Mouse Pointer and Position 
    Cursor at the Beginning of the Line
    Drag: Define Selection from Insertion Cursor
    Shift-Drag: Extend Selection
    Double Click, Shift-Drag: Extend Selection by Whole Words
    Triple Click, Shift-Drag: Extend Selection by Whole Lines
    Ctrl: Position Insertion Cursor without Affecting Selection

    Mouse Button 2:
    Click: Copy Selection into Text at the Mouse Pointer
    Drag:Shift View

    Mouse Button 3: 
    Pop Up Menu Bar

    Meta                  Escape

    


=head1 METHODS

There is no actual API specification, but Workspaces recognize
the following instance methods:

about, create, new, bind, window, text, name, textfont, foreground,
background, filemenu, editmenu, wrap, parent_ws, width, height, x, y,
open, ws_font, ws_setcolor, ws_quit, write_to_disk, menubar, ws_close,
ws_copy, ws_cut, ws_paste, ws_undo, self_help, ws_import, ws_export.

The following class methods are available:

WrapMenuItems, ScrollMenuItems.

The only method that recognizes configuration options is the
constructor, 'new'.  At the moment it the only option it recognizes is
'menubar', which sets a visible (true) or hidden (false) menubar.

=head1 AUTHOR

rkiesling@mainmatter.com (Robert Kiesling)

=head1 REVISION 

$Id: Workspace.pm,v 1.41 2000/09/25 15:16:52 kiesling Exp $

=head1 SEE ALSO:

Tk::overview(1) manual page, perl(1) manual page.

=cut

