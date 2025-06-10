## Code is GPLed, original script by Marko Riedel,
## markoriedelde@gmail.com

package SDKDocument;

use IPC::Open2;
use SDKConfig;
use Tk::Dialog;

my $boardSquare = 50;
my ($thickLine, $thinLine) = (8,1);

my $btnFontFamily = 'Helvetica-Bold';
my $btnFontSize = 16;

my $genbinary = './gensudokuconstr';

my $docindex = 0;

sub new {
    my $class = shift;
    my $mainwin = shift;
    
    my $self = { 'mainwin' => $mainwin};

    $self->{enter} = SDKConfig->new();
    $self->{play} = [];    
    $self->{solution} = 'notfound';
    
    $self->{mode} = 'enter';
    
    $self->{histpos} = -1;

    my $win;
    $self->{window} = $win = $mainwin->Toplevel();

    $docindex++;
    $self->{filename} = "untitled$docindex.sdk";
    $self->{needsname} = 'yes';
    $self->{window}->configure(-title => '(enter mode)' );
    
    my ($lenall, $curx, $cury) =
	($boardSquare*9+4*$thickLine+6*$thinLine-1);

    my $menuFrame = $win->Frame();
    $self->{menuf} = $menuFrame;
    
    $self->{cloneb} = $menuFrame->Button(
	-text => 'Clone', -command => sub {
	    $self->clone();
	    
	    return;
	});
    $self->{cloneb}->{document} = $self;

    $self->{epsb} = $menuFrame->Button(
	-text => 'EPS', -command => sub {
	    $self->eps();
	    
	    return;
	});
    $self->{epsb}->{document} = $self;
    
    $self->{playb} = $menuFrame->Button(
	-text => 'Play', -command => sub {
	    my $clicked = $Tk::widget;
	    my $doc = $clicked->{document};
	    $doc->play();
	    
	    return;
	});
    $self->{playb}->{document} = $self;

    $self->{ingen} = 'no';
    $menuFrame->pack();
    
    $self->{digitsel} = 1;
    my $digitFrame = 
	$win->Frame(-highlightbackground => 'black',
		    -highlightthickness => 4);
    $digitFrame->pack(-after => $menuFrame);
    
    my @digitbtn = ();

    my $digitfont = $mainwin->fontCreate
	(-size => $btnFontSize, -family => $btnFontFamily);
    
    for(my $d=0; $d<10; $d++){
	$digitbtn[$d] = $digitFrame->Radiobutton(
	    -text => ($d>0 ? "  $d  " : '     '),
	    -value => $d,
	    -variable => \$self->{digitsel},
	    -font => $digitfont,
	    -indicatoron => 0);
	$digitbtn[$d]->grid(-row => 0, -column => $d);
    }
    
    my $boardCanvas = $win->Canvas(
	-width => $lenall, -height => $lenall);    
    $boardCanvas->pack(-side => 'bottom');

    $self->{canvas} = $boardCanvas;
    
    $self->{playb}->pack(-side => 'left', -anchor => 'nw');
    $self->{cloneb}->pack(-side => 'left', -anchor => 'nw');
    $self->{epsb}->pack(-side => 'left', -anchor => 'nw');    
    
    $self->{starttime} = -1;
    
    $cury = 0;
    for(my $idx = 0; $idx<=9; $idx++){
	my ($lineWidth) = ($idx % 3 == 0 ? $thickLine : $thinLine);
	$boardCanvas->createRectangle(0,$cury,
				      $lenall,$cury+$lineWidth-1,
				      -fill => 'black');
	$cury += $boardSquare + $lineWidth;
    }
    $curx = 0;
    for(my $idx = 0; $idx<=9; $idx++){
	my ($lineWidth) = ($idx % 3 == 0 ? $thickLine : $thinLine);
	$boardCanvas->createRectangle($curx,0,
				      $curx+$lineWidth-1,$lenall,
				      -fill => 'black');
	$curx += $boardSquare + $lineWidth;
    }

    $boardCanvas->pack();
    
    my ($buttons);

    my $btnfont = $mainwin->fontCreate(-size => 20, -weight => 'bold');
    
    ($curx, $cury) = ($thickLine, $thickLine);
    for(my $row=0; $row<9; $row++){
	$curx = $thickLine;
	for(my $col=0; $col<9; $col++){	    
	    my $btn = $boardCanvas->Button(
		-text => '', -relief => 'flat',
		-disabledforeground => '#007F00',
		-font => $btnfont,
		-command => sub {
		    my $clicked = $Tk::widget;
		    my ($clrow, $clcol) =
			($clicked->{grow},
			 $clicked->{gcol});
		    
		    my ($value) = $self->{digitsel};
		    
		    $clicked->{nvalue} = $value;
		    $clicked->configure(
			-text =>
			($value == 0 ? '' : "$value"));

		    if($self->{mode} eq 'enter'){
			my $cur = $self->{enter};
			$cur->record($clrow, $clcol, $value);

			
			$self->updateGUI();
		    }
		    else{	
			my $hpos = $self->{histpos};
			my $nxt;

			if($hpos == -1){
			    $nxt = SDKConfig->new();
			    $self->{play} = [];
			}
			else{
			    my $pconf = $self->{play}->[$hpos];

			    $nxt = $pconf->copy();
			    splice @{ $self->{play} }, $hpos+1;
			}
			push @{ $self->{play} }, $nxt;
			$self->{histpos} = $hpos+1;

			$nxt->record($clrow, $clcol, $value);

			my $merged = $nxt->merge($self->{enter});

			$self->{undob}->configure(-state => 'normal');
			$self->{redob}->configure(-state => 'disabled');
			
			$self->updateGUI();
			$self->checkMovePoss();
			
			if($merged->isEqual($self->{solution}) &&
			   $self->{starttime} != -1){
			    my $endtime = time();

			    $duration = $endtime- $self->{starttime};
			    my $elapsed = "$duration second(s)";
			    if($duration >= 60){
				my $mins = int($duration/60);
				my $secs = int($duration-$mins*60);
				$elapsed =
				    "$mins minute(s) $secs second(s)";
			    }

			    $self->{starttime} = -1;

			    $win->messageBox(-icon => 'info', -type => 'ok',
					     -title => 'Congratulations!',
					     -message =>
					     "Completed game in $elapsed.");
			}

			$self->{saveb}->configure(-state => 'normal');
		    }
		    
		    return;
		});
	    push @{ $buttons->[$row] }, $btn;

	    $btn->place(-x => $curx+1,
			-y => $cury+1,
			-width => $boardSquare-2, 
			-height => $boardSquare-2);

	    $btn->{grow} = $row;
	    $btn->{gcol} = $col;

	    $btn->{nvalue} = 0;

	    $btn->{document} = $self;
	    
	    $curx += 
		$boardSquare
		+(($col+1) % 3 == 0? $thickLine:$thinLine);
	}
	$cury += 
	    $boardSquare
	    +(($row+1) % 3 == 0? $thickLine:$thinLine);
    }

    # my $wxpos = int(($win->screenwidth  - $win->width ) / 2);
    # my $wypos = int(($win->screenheight - $win->height) / 2);
    # $win->geometry("+$wxpos+$wypos");
    
    $win->protocol('WM_DELETE_WINDOW' => sub {
	if($self->{mode} eq 'play' && 
	   $self->{saveb}->cget(-state) eq 'normal'){
	    my $dialog = $win->Dialog(-text => 'Save changes?',
				      -bitmap => 'question',
				      -title => 'Save?',
				      -default_button => 'Yes',
				      -buttons => [qw/Yes No/]);
	    my $answer = $dialog->Show();
	    if($answer eq 'Yes'){
		return 
		    if not(defined($self->save()));
	    }
	}
	my $docref = $self->{mainwin}->{docref}; my $dx;
	for($dx = 0; $dx < scalar(@$docref); $dx++){
	    last if $docref->[$dx] == $self;
	}
	splice @$docref, $dx, 1;
	
	$self->{window}->destroy(); });
    
    $self->{buttons} = $buttons;
    bless $self, $class;
    
    return $self;
}

sub parseatoffset {
    my $self = shift;
    my $line = shift || [];
    my $offset = shift || 0;

    my $win = $self->{window};
    
    my @data;
    for(my $q=$offset; $q<$offset+9; $q++){
	if(not(defined($line->[$q]))){
	    $win->messageBox(-icon => 'error', -type => 'ok',
			     -title => 'Alert',
			     -message => 
			     "missing data at offset $q");
	    return undef;
	}

	if($line->[$q] !~ /([0-9]\s){9}/){
	    $win->messageBox(-icon => 'error', -type => 'ok',
			     -title => 'Alert',
			     -message => 'looking for nine digits');
	    return undef;
	}

	chomp $line->[$q];
	my (@vals) = split /\s/, $line->[$q];
	push @data, [ @vals];
    }

    return SDKConfig->new(\@data);
}

sub updateGUI {
    my $self = shift;

    my $docorrect = ${ $self->{mainwin}->{correctref} };
    my $doconsist = ${ $self->{mainwin}->{consistref} };

    my $enterstage = ($self->{mode} eq 'enter' ? 1 : 0);

    my $canvas = $self->{canvas};
    
    my $hpos = $self->{histpos};

    my $merged = 
	($enterstage ? 
	 undef : 
	 ($hpos >= 0 ? $self->{play}[$hpos]->merge($self->{enter}) :
	  $self->{enter}));

    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    my $btn = $self->{buttons}->[$row][$col];

	    my $value = $self->{enter}->[$row][$col];

	    my $color = 'black';
	    if($enterstage){
		if($doconsist && $value>0 &&
		   !($self->{enter}->isConsistent($row, $col))){
		    $color = 'orange';
		}
	    }
	    else{
		$value = $merged->[$row][$col];
		if($docorrect &&
		   $value != $self->{solution}->[$row][$col]){
		    $color = 'red';
		}
		elsif($doconsist && $value>0 &&
		   !($merged->isConsistent($row, $col))){
		    $color = 'orange';
		}
	    }
	    ## $canvas->itemconfigure($rect, -outline => $color);
	    
	    my $state = 'normal'; 
	    my $text = ($value > 0 ? $value : '');
	    if(!$enterstage){
		if($self->{enter}->[$row][$col] != 0){
		    $state = 'disabled';
		}
		elsif($hpos == -1 || 
		      $self->{play}[$hpos]->[$row][$col] == 0){
		    $text = '';
		}
	    }
	    
	    $btn->configure(-foreground => $color,
			    -state => $state, -text => $text);
	}
    }
}    

sub startPlayPhase {
    my $self = shift;
    my $menuFrame = $self->{menuf};

    $self->{playb}->destroy();


    $self->{solveb} = $menuFrame->Button(
	-text => 'Solve', -command => sub {
	    splice @{ $self->{play} }, $self->{histpos}+1;
	    
	    push @{ $self->{play} },
		$self->{enter}->ontop($self->{solution});
	    $self->{histpos}++;
	    
	    $self->{undob}->configure(-state => 'normal');
	    $self->{redob}->configure(-state => 'disabled');

	    $self->updateGUI();
	    $self->checkMovePoss();
	    
	    return;
	});
    $self->{solveb}->{document} = $self;

    $self->{moveb} = $menuFrame->Button(
	-text => 'Move', -command => sub {
	    my $hpos = $self->{histpos};

	    my ($nxt, $merged);
	    if($hpos == -1){
		$nxt = SDKConfig->new();
		$merged = $self->{enter}->copy();
	    }
	    else{
		$nxt = $self->{play}[$hpos]->copy();
		$merged = $self->{play}[$hpos]->merge($self->{enter});
	    }

	    my $move = 
		$merged->alldeterm() || 
		$merged->allcompat() ||
		$merged->oneclue($self->{solution});
	    if(defined($move)){
		splice @{ $self->{play} }, $hpos+1;
		$nxt->record(@$move);

		push @{ $self->{play} }, $nxt;

		$self->{histpos}++;
		
		$self->{undob}->configure(-state => 'normal');
		$self->{redob}->configure(-state => 'disabled');

		$self->updateGUI();
		$self->checkMovePoss();

		$self->{saveb}->configure(-state => 'normal');
	    }

	    return;
	});
    $self->{moveb}->{document} = $self;
    
    $self->{undob} = $menuFrame->Button(
	-text => 'Undo', -state => 'disabled',
	-command => sub {
	    my $hpos = $self->{histpos};
	    $hpos--; $self->{histpos} = $hpos;

	    if($hpos == -1){
		$self->{undob}->configure(-state => 'disabled');
	    }
	    $self->{redob}->configure(-state => 'normal');
	    
	    $self->updateGUI();
	    $self->checkMovePoss();
	    
	    return;
	});
    $self->{undob}->{document} = $self;


    $self->{redob} = $menuFrame->Button(
	-text => 'Redo', -state => 'disabled',
	-command => sub {
	    my $hpos = $self->{histpos};
	    $hpos++; $self->{histpos} = $hpos;

	    $self->{undob}->configure(-state => 'normal');
	    if($hpos == scalar(@{ $self->{play} })-1){
		$self->{redob}->configure(-state => 'disabled');
	    }
	    
	    $self->updateGUI();
	    $self->checkMovePoss();
	  
	    return;
	});
    $self->{redob}->{document} = $self;

    $self->{saveb} = $menuFrame->Button(
	-text => 'Save',
	-command => sub {
	    $self->save();
	});
    $self->{saveb}->{document} = $self;

    
    $self->{saveb}->pack(-side => 'left', -anchor => 'nw');
    $self->{solveb}->pack(-side => 'left', -anchor => 'nw');
    $self->{moveb}->pack(-side => 'left', -anchor => 'nw');    
    $self->{undob}->pack(-side => 'left', -anchor => 'nw');
    $self->{redob}->pack(-side => 'left', -anchor => 'nw');


    $self->{undob}->configure(
	-state => ($self->{histpos} 
		   >= 0 ? 'normal' : 'disabled'));
    $self->{redob}->configure(
	-state => ($self->{histpos} 
		   < scalar(@{$self->{play}})-1 ? 'normal' : 'disabled'));

    # $self->{saveb}->configure(-state => 'disabled');
}

sub save {
    my $self = shift;

    my $mainwin = $self->{mainwin};

    if($self->{needsname} eq 'yes'){
	my @ext = (
	    ["All Sudoku Files", [qw/*.sdk/]],
	    ["All files", ['*']]);

	my $answer = $mainwin->getSaveFile(
	    -initialfile => $self->{filename},
	    -filetypes => \@ext, 
	    -defaultextension => '.sdk');

	if(defined($answer) and length($answer)>0){
	    $self->{filename} = $answer;
	}
	else{
	    return undef;
	}
    }


    my $docorrect = ${ $self->{mainwin}->{correctref} };
    my $doconsist = ${ $self->{mainwin}->{consistref} };
    my $guesswork = ${ $self->{mainwin}->{guessworkref} };
    
    my $hist = scalar(@{ $self->{play}});
    my $hpos = $self->{histpos};
    
    open $OUT, '>', $self->{filename};
    print $OUT "SimpleSudoku $hist $hpos ";
    print $OUT "$docorrect $doconsist $guesswork\n";

    $self->{solution}->print2fh($OUT);
    $self->{enter}->print2fh($OUT);

    foreach my $conf (@{ $self->{play}}){
	$conf->print2fh($OUT);
    }
    
    close $OUT;
    
    $self->{needsname} = 'no';

    $self->{filename} =~ /([^\/]+)$/;
    my $lastcomp = $1;
    $self->{window}->configure(-title => $lastcomp);

    $self->{saveb}->configure(-state => 'disabled');
    
    return 1;
}

sub eps {
    my $self = shift;

    return undef if $self->{ingen} eq 'yes';
    
    my $filenoext = "untitled$docindex";
    if($self->{needsname} eq 'no'){
	$self->{filename} =~ /([^\/]+)(\.[^\/]+)$/;
	$filenoext = $1;
    }

    my @ext = (
	["All EPS Files", [qw/*.eps/]],
	["All files", ['*']]);

    my $answer = $self->{mainwin}->getSaveFile(
	-initialfile => "$filenoext.eps",
	-filetypes => \@ext, 
	-defaultextension => '.eps');

    if(defined($answer) and length($answer)>0){
	open $EPS, ">$answer";
	print $EPS "%!PS-Adobe-3.0 EPSF-3.0\n";

	my $totaldim = $thickLine*4+$thinLine*6+9*$boardSquare;
	
	print $EPS "%%BoundingBox: 0 0 $totaldim $totaldim\n";
	print $EPS "%%Creator: SimpleSudoku\n";
	print $EPS "%%Pages: 1\n";
	print $EPS "%%EndComments\n\n";

	print $EPS "/SQSIZE $boardSquare def\n";
	print $EPS "/ALLSIZE $totaldim def\n";

	my ($curx, $cury) = (0, 0);
	for(my $row=0; $row<10; $row++){
	    my $lw = ($row % 3 == 0 ? $thickLine : $thinLine);
	    print $EPS "0 $cury ";
	    print $EPS "ALLSIZE $lw ";
	    print $EPS "rectfill\n";

	    $cury += $lw+$boardSquare;
	}

	for(my $col=0; $col<10; $col++){
	    my $lw = ($col % 3 == 0 ? $thickLine : $thinLine);
	    print $EPS "$curx 0 ";
	    print $EPS "$lw ALLSIZE ";
	    print $EPS "rectfill\n";

	    $curx += $lw+$boardSquare;
	}

	print $EPS "/$btnFontFamily findfont ";
	print $EPS "$btnFontSize 96 72 div mul scalefont setfont\n";

	print $EPS "/CharHeight { 100 100 moveto true charpath pathbbox\n";
	print $EPS "exch pop 3 -1 roll pop exch sub } def\n";
	

	my $hpos = $self->{histpos};
	my $merged = 
	    ($hpos >= 0 ? $self->{play}[$hpos]->merge($self->{enter}) :
	     $self->{enter});
	
	($curx, $cury) = ($thickLine, $thickLine);
	for(my $row=0; $row<9; $row++){
	    for(my $col=0; $col<9; $col++){
		my $val = $merged->[8-$row][$col];
		if($val > 0){
		    print $EPS "gsave $curx $cury translate\n";
		
		    print $EPS "($val) stringwidth pop\n";
		    print $EPS "$boardSquare exch sub 2 div\n";
		    print $EPS "$boardSquare ($val) CharHeight sub 2 div\n";
		    print $EPS "moveto ($val) show grestore\n";
		}
		$curx += $boardSquare
		    + ((($col+1) % 3 == 0) ? $thickLine : $thinLine);
	    }
	    $curx = $thickLine;
	    $cury += $boardSquare
		+ ((($row+1) % 3 == 0) ? $thickLine : $thinLine);
	}

	print $EPS "showpage\n";
	
	close $EPS;
    }
}    
    
sub generate {
    my $self = shift; my $boardtype = shift || 1;

    my $win = $self->{window};

    my $cluemx = ${ $self->{mainwin}->{clueref} };

    my $subseed = int(rand(1<<20));
    
    $win->configure(-cursor => 'watch');

    $self->{ingen} = 'yes';
    
    $self->{playb}->configure(-state => 'disabled');
    $self->{cloneb}->configure(-state => 'disabled');
    $self->{epsb}->configure(-state => 'disabled');

    $win->configure(-title => '(computing)' );
    $win->update();
    
    my $guessflag =
	(${ $self->{mainwin}->{guessworkref} } == 1 ?
	 "" : "-x");
    
    my $cmd = 
	"$genbinary -g -t 30 -c $cluemx " 
	. "-r $subseed $guessflag -y $boardtype";
    print "$cmd\n";
    my @lines = `$cmd`;

    $self->{playb}->configure(-state => 'normal');
    $self->{cloneb}->configure(-state => 'normal');
    $self->{epsb}->configure(-state => 'normal');

    $win->configure(-cursor => '');
    
    if(not(defined($lines[0])) ||
       $lines[0] =~ /NOTUNIQUE|NOSOLUTION/){
	$win->messageBox(-icon => 'error', -type => 'ok',
			 -title => 'Alert',
			 -message => 'couldn\'t generate sudoku');
	return undef;
    }

    if($lines[0] =~ /TIMEOUT/){
	$win->messageBox(-icon => 'error', -type => 'ok',
			 -title => 'Alert',
			 -message => 
			 ('couldn\'t generate sudoku' .
			  ' (timeout, try again)'));
	return undef;
    }
       
    my $result = $self->parseatoffset(\@lines, 1);
    return if not defined($result);

    my $mask = $self->parseatoffset(\@lines, 9+1);
    return if not defined($mask);

    $self->{enter} = $mask;
    $self->{histpos} = -1; $self->{solution} = $result;
    ## $self->{play}->[0] = $mask;

    $self->{mode} = 'play';

    $self->{starttime} = time();
    
    $self->startPlayPhase();
    $self->updateGUI();
    $self->checkMovePoss();
    
    $self->{mainwin}->{setrandsbtn}->configure(
    	-state => 'normal');

    $self->{window}->configure(-title => $self->{filename});
    $self->{ingen} = 'no';
    
    return 0;
}
    

sub play {
    my $self = shift;

    my $win = $self->{window};

    return undef if $self->{ingen} eq 'yes';
    
    my $cluemx = ${ $self->{mainwin}->{clueref} };
    my $guessw = ${ $self->{mainwin}->{guessworkref} };
    
    my $subseed = int(rand(1<<20));
    
    $win->configure(-cursor => 'watch');
    $win->update();

    my @genexec = ($genbinary, "-s", "-t", 20000);
    push @genexec, "-x" if $guessw == 0;
    
    my $pid = open2($OUT, $IN, @genexec);
    $self->{enter}->print2fh($IN); close($IN);
    my @lines = <$OUT>; close($OUT);
    $win->configure(-cursor => '');

    if(not(defined($lines[0]))){
	$win->messageBox(-icon => 'error', -type => 'ok',
			 -title => 'Alert',
			 -message => 'no output from solver');
	return;
    }

    if($lines[0] =~ /TIMEOUT/){
	$win->messageBox(-icon => 'error', -type => 'ok',
			 -title => 'Alert',
			 -message => 'timeout from solver');
	return;
    }

    if($lines[0] =~ /NOTUNIQUE/){
	$win->messageBox(-icon => 'error', -type => 'ok',
			 -title => 'Alert',
			 -message => 'no unique solution');
	return;
    }

    if($lines[0] =~ /NOSOLUTION/){
	my $const = ($lines[0] =~ /CONST/ ? ' (inconsistent)' : '');
	my $guess = ($guessw ? 
		     ' with guessing/backtracking allowed' : 
		     ' with guessing/backtracking turned off');
	$win->messageBox(-icon => 'error', -type => 'ok',
			 -title => 'Alert',
			 -message => 'no solution found' 
			 . $const . $guess);
	return;
    }

    $self->{solution} = $self->parseatoffset(\@lines, 0);
    return if not defined($self->{solution});
    
    $self->{histpos} = -1;
    # $self->{play}->[0] = $self->{enter};

    $self->{mode} = 'play';

    $self->{starttime} = time();

    $self->{window}->configure(-title => $self->{filename});
    
    $self->startPlayPhase();
    $self->updateGUI();    
}

sub open {
    my $self = shift;
    my $srcfile = shift;
    
    my $win = $self->{window};

    open $IN, $srcfile;

    my $head = <$IN>;
    if(defined($head) && $head =~ 
       /^SimpleSudoku (\d+) (-?\d+) (\d) (\d) (\d)$/){
	my ($histcount, $histpos, $docorrect, $doconsist, $guesswork)
	    = ($1, $2, $3, $4, $5);

	${ $self->{mainwin}->{correctref} } = $docorrect;
	${ $self->{mainwin}->{consistref} } = $doconsist;
	${ $self->{mainwin}->{guessworkref} } = $guesswork;
	
	my @rest = <$IN>;
	
	$self->{solution} = $self->parseatoffset(\@rest, 0);
	$self->{enter} = $self->parseatoffset(\@rest, 9);
	for(my $hpos=0; $hpos < $histcount; $hpos++){
	    push @{ $self->{play} },
		$self->parseatoffset(\@rest, 18+9*$hpos);
	}

	$self->{filename} = $srcfile;
	$self->{needsname} = 'no';

	$self->{histpos} = $histpos;

	$self->{filename} =~ /([^\/]+)$/;
	my $lastcomp = $1;
	$win->configure(-title => $lastcomp);

	$self->{mode} = 'play';
	$self->updateGUI();

	$self->startPlayPhase();
	$self->{saveb}->configure(-state => 'disabled');
	
	if($histpos == -1 || 
	   $self->{play}[$histpos]->occupied() < 81){
	    $self->{starttime} = time();
	}
	else{
	    $self->{starttime} = -1;
	}

	$self->checkMovePoss();
    }
    
    close $IN;
}

sub clone {
    my $self = shift;
    my $mainwin = $self->{mainwin};

    return undef if $self->{ingen} eq 'yes';
    
    my $other = SDKDocument->new($mainwin);

    my $histcount = scalar(@{ $self->{play} });
	
    $other->{solution} = 
	($self->{mode} eq 'enter' ?
	 undef : $self->{solution}->copy());
    $other->{enter} = $self->{enter}->copy();
    
    for(my $hpos=0; $hpos < $histcount; $hpos++){
	push @{ $other->{play} },
	    $self->{play}[$hpos]->copy();
    }

    $other->{filename} = "untitled$docindex.sdk";
    $other->{needsname} = 'yes';

    $other->{window}->configure(
	-title => ($self->{mode} eq 'enter' ?
		   '(enter mode)' : $other->{filename}));
    
    $other->{histpos} = $self->{histpos};

    $other->{mode} = $self->{mode};
    $other->updateGUI();
    
    if($other->{mode} ne 'enter'){
	$other->startPlayPhase();
	$other->checkMovePoss();
	$other->{starttime} = $self->{starttime};
    }

    return $other;
}

sub checkMovePoss {
    my $self = shift;
    my $hpos = $self->{histpos};

    my $moveposs;
    
    if($hpos >= 0){
	my $agr = $self->{play}[$hpos]->agree($self->{solution});
	my $merged = $self->{play}[$hpos]->merge($self->{enter});

	$moveposs =
	    defined($agr) && 
	    (defined($merged->allcompat()) ||
	     defined($merged->alldeterm()) ||
	     defined($merged->oneclue($self->{solution})));
    }
    else{
	$moveposs =
	    $self->{enter}->occupied() < 81 &&
	    (defined($self->{enter}->allcompat()) ||
	     defined($self->{enter}->alldeterm()) ||
	     defined($self->{enter}->oneclue($self->{solution})));
    }
    
    $self->{moveb}->configure(-state => 
			      ($moveposs ? 
			       'normal' : 'disabled'));
}

1;
