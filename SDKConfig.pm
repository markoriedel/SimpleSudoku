## Code is GPLed, original script by Marko Riedel,
## markoriedelde@gmail.com


package SDKConfig;

sub new {
    my $class = shift;
    my $data = shift;

    my $self = $data;

    if(not(defined($self))){
	$self = 
	    [ [ (0) x 9], [ (0) x 9], [ (0) x 9],
	      [ (0) x 9], [ (0) x 9], [ (0) x 9],
	      [ (0) x 9], [ (0) x 9], [ (0) x 9] ];
    }
    
    bless $self, $class;
    
    return $self;
}

sub print2fh {
    my ($self, $fh) = @_;

    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    print $fh $self->[$row][$col];
	    print $fh ($col==8 ? "\n" : ' ');
	}	    
    }
}

sub occupied {
    my $self = shift;
    my $count = 0;


    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    $count++  if $self->[$row][$col] > 0;
	}
    }

    return $count;
}

sub copy {
    my $self = shift;
    my @cpdata;

    for(my $row=0; $row<9; $row++){
	push @cpdata, [ @{ $self->[$row] } ];
    }
    
    return SDKConfig->new(\@cpdata);
}

sub ontop {
    my $self = shift;
    my $other = shift;
    
    my @tpdata;

    for(my $row=0; $row<9; $row++){
	my @tprow;
	for(my $col=0; $col<9; $col++){
	    push @tprow,
		($self->[$row][$col] == 0 ?
		 $other->[$row][$col] : $self->[$row][$col]);
	}
	push @tpdata, \@tprow;
    }

    return SDKConfig->new(\@tpdata);
}

sub merge {
    my $self = shift;
    my $other = shift;
    my @mdata;
    
    for(my $row=0; $row<9; $row++){
	my @rowdata =  ();
	for(my $col=0; $col<9; $col++){
	    my $val1 = $self->[$row][$col];
	    my $val2 = $other->[$row][$col];

	    if($val1 != 0){
		push @rowdata, $val1;
	    }
	    elsif($val2 != 0){
		push @rowdata, $val2;
	    }
	    else{
		push @rowdata, 0;
	    }
	}

	push @mdata, \@rowdata;
    }

    return SDKConfig->new(\@mdata);
}

sub isEqual {
    my ($self, $other) = @_;

    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    my $val1 = $self->[$row][$col];
	    my $val2 = $other->[$row][$col];

	    return 0 if $val1 != $val2;
	}
    }

    return 1;
}

sub todata {
    my $self = shift;

    my $buf = '';

    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    $buf .= "$self->[$row][$col]";
	    $buf .= ($col==8 ? "\n" : " ");
	}
    }

    return $buf;
}
    

sub record {
    my ($self, $row, $col, $val) = @_;
    $self->[$row][$col] = $val;

    return $val;
}

sub isConsistent {
    my ($self, $row, $col) = @_;
    my $val = $self->[$row][$col];

    for(my $xcol=0; $xcol<9; $xcol++){
	return 0
	    if $val == $self->[$row][$xcol] && $xcol != $col;
    }

    for(my $xrow=0; $xrow<9; $xrow++){
	return 0
	    if $val == $self->[$xrow][$col] && $xrow != $row;
    }

    my ($clustX, $clustY) =
	(($row-($row %3))/3, ($col-($col %3))/3);

    for(my $xrow=0; $xrow < 3; $xrow++){
	for(my $xcol=0; $xcol < 3; $xcol++){
	    my ($xx, $yy) = ($clustX*3+$xrow, $clustY*3+$xcol);
	    return 0
		if $val == $self->[$xx][$yy] &&
		($xx != $row || $yy != $col);
	}
    }

    return 1;
}

sub agree {
    my $self = shift;
    my $other = shift;

    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    if($self->[$row][$col] != 0 &&
	       $self->[$row][$col] != $other->[$row][$col]){
		return undef;
	    }
	}
    }

    return 1;
}

sub onedeterm {
    my ($self, $row, $col) = @_;
    my %seen;
    
    for(my $xcol=0; $xcol<9; $xcol++){
	$seen{$self->[$row][$xcol]} = 1
	    if $xcol != $col;
    }

    for(my $xrow=0; $xrow<9; $xrow++){
	$seen{$self->[$xrow][$col]} = 1
	    if $xrow != $row;
    }

    my ($clustX, $clustY) =
	(($row-($row %3))/3, ($col-($col %3))/3);

    for(my $xrow=0; $xrow < 3; $xrow++){
	for(my $xcol=0; $xcol < 3; $xcol++){
	    my ($xx, $yy) = ($clustX*3+$xrow, $clustY*3+$xcol);
	    $seen{$self->[$xx][$yy]} = 1
		if ($xx != $row || $yy != $col);
	}
    }

    my @possibles =
	grep { !exists($seen{$_}) } (1..9);

    return \@possibles;
}


sub alldeterm {
    my $self = shift;

    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    my $val = $self->[$row][$col];
	    if($val == 0){
		my $poss = $self->onedeterm($row, $col);
		if(scalar(@$poss) == 1){
		    return [ $row, $col, $poss->[0]];
		}
	    }
	}
    }

    return undef;
}


sub oneclue {
    my $self = shift;
    my $sol = shift;

    my @options = ();
    
    for(my $row=0; $row<9; $row++){
	for(my $col=0; $col<9; $col++){
	    my $val = $self->[$row][$col];
	    if($val == 0){
		my $poss = $self->onedeterm($row, $col);
		push @options, 
		    [ $row, $col, scalar(@$poss)];
	    }
	}
    }
    
    return undef if scalar(@options) == 0;
    
    my @osorted = sort { $a->[2] <=> $b->[2] } @options;
    my $clue = $osorted[0];

    return [ $clue->[0], $clue->[1],
	     $sol->[$clue->[0]][$clue->[1]] ];
}



sub iscompat {
    my ($self, $x, $y, $val) = @_;

    for(my $row=0; $row<9; $row++){
	return undef if $self->[$row][$y] == $val;
    }

    for(my $col=0; $col<9; $col++){
	return undef if $self->[$x][$col] == $val;
    }
    
    my ($clustX, $clustY) =
	(($x-($x %3))/3, ($y-($y %3))/3);

    for(my $row=0; $row < 3; $row++){
	for(my $col=0; $col < 3; $col++){
	    my ($xx, $yy) = ($clustX*3+$row, $clustY*3+$col);
	    return undef if $self->[$xx][$yy] == $val;
	}
    }

    return 1;
}

sub allcompat {
    my $self = shift;
    
    for(my $val=1; $val<=9; $val++){
	for(my $clustX=0; $clustX<3; $clustX++){
	    for(my $clustY=0; $clustY<3; $clustY++){
		my @cmpt;
		for(my $x=0; $x<3; $x++){
		    for(my $y=0; $y<3; $y++){
			my ($row, $col) =
			    ($clustX*3+$x, $clustY*3+$y);
			push @cmpt, [$row, $col]
			    if $self->[$row][$col] == 0 &&
			    $self->iscompat($row, $col, $val)
		    }
		}

		return [ @{ $cmpt[0] }, $val ]
		    if scalar(@cmpt) == 1;
	    }
	}

	for(my $row=0; $row<9; $row++){
	    my @cmpt;
	    for(my $col=0; $col<9; $col++){
		push @cmpt, [$row, $col]
		if $self->[$row][$col] == 0 &&
		    $self->iscompat($row, $col, $val)
	    }

	    return [ @{ $cmpt[0] }, $val ]
		if scalar(@cmpt) == 1;
	}

	for(my $col=0; $col<9; $col++){
	    my @cmpt;
	    for(my $row=0; $row<9; $row++){
		push @cmpt, [$row, $col]
		if $self->[$row][$col] == 0 &&
		    $self->iscompat($row, $col, $val)
	    }

	    return [ @{ $cmpt[0] }, $val ]
		if scalar(@cmpt) == 1;
	}
    }

    return undef;
}

1;
