package TS::Case;

use strict;
use Carp;

our $AUTOLOAD;

my %attr  = (name=>'', cf=>[], param=>[], restart=>0, os=>'', nozfb=>0, retry=>0, retry_type=>"", master=>0);

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
  confess "Name cannot be blank" unless $self->{name};
  $self->{cf} ||= [];
  $self->{param} ||= [];
  $self->{restart} ||= 0;
  $self->{os} ||= '';
  return $self;
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

sub get_cmd{
  return "In TS::Case: To do function";
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
