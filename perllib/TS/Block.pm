package TS::Block;

use strict;

our $AUTOLOAD;

my %attr  = (name=>'', cf=>[], param=>[], case=>[], restart=>0, tf_ex=>0, nozfb=>0, master=>0);

sub new{
  my $class=shift;
  my %params = @_;
  my $self = {};
  bless $self, $class;
  for my $k(keys %params){
    if( exists $attr{$k}){
      $self->{$k} = $params{$k};
    }else{
      die "Invalid attr: $k was set to ".(defined $params{$k} ? $params{$k} : '' );
    }
  }
  die "Name cannot be blank" unless $self->{name};
  $self->{cf} ||= [];
  $self->{param} ||= [];
  $self->{case} ||= [];
  $self->{restart} ||= 0;
  $self->{tf_ex} ||= 0;
  return $self;
}

sub clone{
  my $self = shift;
  my $new = new TS::Block(name=>$self->{name});
  for my $k(keys %attr){
    my $ref = ref $attr{$k};
    if($ref eq ''){
      $new->{$k} = $self->{$k};
    }elsif($ref eq 'ARRAY'){
      $new->{$k} = [@{$self->{$k}}]
    }elsif($ref eq 'HASH'){
      $new->{$k} = {%{$self->{$k}}}
    }else{
      $new->{$k} = $self->{$k}; # reuse cases
    }
  }
  return $new;
}

sub add_param{
  my $self = shift;
  my $p = shift;
  if($p){
    my $has_flag = 0;
    for(@{$self->{param}}){
      if($p eq $_){
        $has_flag = 1;
        last;
      }
    }
    push @{$self->{param}}, $p unless $has_flag;
  }
  return $self;
}

sub remove_param{
  my $self = shift;
  my $p = shift;
  if($p){
    my @p;
    for(@{$self->{param}}){
      push @p, $_ unless($p eq $_);
    }
    $self->{param} = \@p;
  }else{
    $self->{param} = [] unless $p;
  }
  return $self;
}

sub add_cf{
  my $self = shift;
  my $p = shift;
  if($p){
    my $has_flag = 0;
    for(@{$self->{cf}}){
      if($p eq $_){
        $has_flag = 1;
        last;
      }
    }
    push @{$self->{cf}}, $p unless $has_flag;
  }
  return $self;
}

sub remove_cf{
  my $self = shift;
  my $p = shift;
  if($p){
    my @p;
    for(@{$self->{cf}}){
      push @p, $_ unless($p eq $_);
    }
    $self->{cf} = \@p;
  }else{
    $self->{cf} = [] unless $p;
  }
  return $self;
}

sub add_case{
  my $self = shift;
  my $case = shift;
  push @{$self->{case}}, $case;
  return $self;
}

sub clear_case{
  my $self = shift;
  $self->{case} = [];
  return $self;
}

sub actions{
  my $self = shift;
  return $self->case();
}

sub get_cmd{
  return "In TS::Block: To do function";
}

sub AUTOLOAD{
  my $self = shift;
  my $sub = $AUTOLOAD;
  $sub =~ s/.*:://;
  if(exists $attr{$sub}){
    $self->{$sub} = $_[0] if @_ > 0;
    return $self->{$sub};
  }else{
    die "Cannot find method $AUTOLOAD\n";
  }
}

1;
__END__
