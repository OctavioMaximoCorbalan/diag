package TS::Func;

use strict;

our $AUTOLOAD;

my %attr  = (name=>'', list=>[], param=>[]);

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
  $self->{list} ||= [];
  $self->{param} ||= [];
  return $self;
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