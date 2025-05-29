#! /usr/bin/perl -w
#

## Code is GPLed, original script by Marko Riedel,
## markoriedelde@gmail.com

use strict;
use warnings;

use Tk;
use Tk::Dialog;

use lib '.';
use SDKConfig;
use SDKDocument;

my @documents;

my $mainwin = tkinit(-title => 'Simple Sudoku');
$mainwin->{docref} = \@documents;

my $bannerfont = $mainwin->fontCreate(-size => 36);
my $banner = $mainwin->Label(-text => 'Sudoku Main',
			     -font => $bannerfont);
$banner->pack();

my $menuFrame = $mainwin->Frame();

my $quitbtn = $menuFrame->Button(
    -text => 'Quit',
    -command => sub { 
	my $dx = 0;
	for($dx=0; $dx < scalar(@documents); $dx++){
	    last if ($documents[$dx]->{mode} eq 'enter' ||
		     $documents[$dx]->{saveb}->cget(-state)
		     eq 'normal');
	}

	if($dx < scalar(@documents)){
	    my $dialog = $mainwin->Dialog(-text => 'Review changed documents?',
					  -bitmap => 'question',
					  -title => 'Save?',
					  -default_button => 'Yes',
					  -buttons => [qw/Yes No/]);
	    
	    my $answer = $dialog->Show();
	    return if $answer eq 'Yes';
	}

	$mainwin->destroy(); });

$quitbtn->grid(-row => 0, -column => 0);

my $clues = 36;
$mainwin->{clueref} = \$clues;
 
my $enterbtn = $menuFrame->Button(
    -text => 'Enter',
    -command => sub { 
	push @documents, 
	    SDKDocument->new($mainwin); 
    });
$enterbtn->grid(-row => 0, -column => 1);

my $genbtn = $menuFrame->Button(
    -text => 'Generate',
    -command => sub { 
	my $doc = SDKDocument->new($mainwin);
	my $type = 1+int(rand(4));
	
	if(defined($doc->generate($type))){
	    push @documents, $doc;
	}
	else{
	    $doc->{window}->destroy();
	}
    });
$genbtn->grid(-row => 0, -column => 2);


my $openbtn = $menuFrame->Button(
    -text => 'Open',
    -command => sub {
	my @ext = (
	    ["All Sudoku Files", [qw/*.sdk/]],
	    ["All files", ['*']]);

	my $answer = $mainwin->getOpenFile(
	    -filetypes => \@ext, 
	    -defaultextension => '.sdk');

	if(defined($answer) and length($answer)>0){
	    push @documents, 
		SDKDocument->new($mainwin);
	    $documents[-1]->open($answer);
	}
    });
$openbtn->grid(-row => 0, -column => 3);


my $clueItems = [
    [Radiobutton => '36 clues', -state => 'normal',
     -value => 36, -variable => \$clues],
    [Radiobutton => '32 clues', -state => 'normal',
     -value => 32, -variable => \$clues],
    [Radiobutton => '30 clues',  -state => 'normal',
     -value => 30, -variable => \$clues],
    [Radiobutton => '28 clues',  -state => 'normal',
     -value => 28, -variable => \$clues],
    [Radiobutton => '26 clues',  -state => 'normal',
     -value => 26, -variable => \$clues],
    [Radiobutton => '24 clues',  -state => 'normal',
     -value => 24, -variable => \$clues],
    ];

my $cluebtn = 
    $menuFrame->Menubutton(-menuitems => $clueItems,
			 -tearoff => 0, -relief => 'raised',
			 -text => 'Clues');
$cluebtn->grid(-row => 0, -column => 4);


$menuFrame->pack();

my $configFrame = $mainwin->Frame();

my $correct = 1;

my $correctBtn = $configFrame->Checkbutton(
    -text => 'correct',
    -command => sub {
	foreach my $doc (@documents){
	    $doc->updateGUI();
	}
    }, 
    -variable => \$correct);
$correctBtn->grid(-row => 0, -column => 0);

$mainwin->{correctref} = \$correct;

my $consistent  = 1;

my $consistentBtn = $configFrame->Checkbutton(
    -text => 'consistent',
    -command => sub {
	foreach my $doc (@documents){
	    $doc->updateGUI();
	}
    }, 
    -variable => \$consistent);
$consistentBtn->grid(-row => 0, -column => 1);

$mainwin->{consistref} = \$consistent;


my $guesswork = 0;

my $guessworkBtn = $configFrame->Checkbutton(
    -text => 'guesswork',
    -variable => \$guesswork);
$guessworkBtn->grid(-row => 0, -column => 2);

$mainwin->{guessworkref} = \$guesswork;

$configFrame->pack();

my $randseed = time() % (1<<20);
my $randFrame = $mainwin->Labelframe(
    -text => 'Random Number Seed');
$randFrame->configure(-labelanchor => 'n');

my $randText = $randFrame->Text(-height => 1, -width => 10);
$randText->insert('1.0', $randseed);
$randText->grid(-row => 0, -column => 0);

my $setrandsBtn;
$setrandsBtn = $randFrame->Button(
    -text => 'Set',
    -command => sub {
	my $value = $randText->get('1.0', 'end');
	if($value !~ /^\d+$/){
	    $mainwin->messageBox(-icon => 'error', -type => 'ok',
				 -title => 'Alert',
				 -message => 'number required');
	    return;
	}

	# $setrandsBtn->configure(-state => 'disabled');
	srand($value);
    });
$setrandsBtn->grid(-row => 0, -column => 1);

$mainwin->{setrandsbtn} = $setrandsBtn;

$randFrame->pack();

$mainwin->after(300, sub {
    my $wxpos = int(($mainwin->screenwidth  - $mainwin->width ) / 2);
    my $wypos = int(($mainwin->screenheight - $mainwin->height) / 2);
    $mainwin->geometry("+$wxpos+$wypos");});

foreach my $arg (@ARGV){
    if (-e $arg && -r $arg && $arg =~ /\.sdk$/){
	push @documents, 
	    SDKDocument->new($mainwin);
	$documents[-1]->open($arg);
    }
}

srand($randseed);
$mainwin->MainLoop;

