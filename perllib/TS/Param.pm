package TS::Param;

use strict;

our $AUTOLOAD;

my %attr  = (
  name=>{type=>"string", can_null=>0},
  type=>{type=>"string", default=>"flag", can_null=>1, in=>"flag|integer|float|string|array"},
  opts=>{type=>"array", can_null=>1},
);

sub new{
  my $class=shift;
  my %params = @_;
  my $self = {};
  bless $self, $class;
  for my $k(keys %params){
    if( _good_attr($k, $params{$k})){
      $self->{$k} = $params{$k};      
    }else{
      die "Invalid attr: $k was set to ".(defined $params{$k} ? $params{$k} : '' );
    }
  }
  return $self;
}

sub to_arg_format{
  my $self = shift;
  my $t = '';
  if($self->{type} eq 'string'){
    $t = '=s';
  }elsif($self->{type} eq 'integer'){
    $t = '=i';
  }
  return "$self->{name}$t";
}

sub name{
  my $self = shift;
  return $self->{name};
}

sub type{
  my $self = shift;
  return $self->{type};
}

sub opts{
  my $self = shift;
  return $self->{opts};
}

sub test_opt{
  my $self = shift;
  my $opt = shift;
  if($self->{opts} and @{$self->{opts}}){
    return _in_array($opt, @{$self->{opts}});
  }else{
    return 1;
  }
}

sub _good_attr{
  my $k = shift;
  my $v = shift;
  return 0 unless defined $attr{$k};
  if(not defined $v){
    return $attr{$k}{can_null} ? 1 : 0;
  } # filter out undefined $v
  
  my $sub = "_is_$attr{$k}{type}";
  my $sub = \&$sub;
  return 0 unless &$sub($v); # check type

  my @in;
  @in = split '\|', $attr{$k}{in} if defined $attr{$k}{in};
  if(@in){
    return _in_array($v, @in);
  }else{
    return 1;
  }
}

sub _in_array{
  my $k = shift;
  my @a = @_;
  for(@a){
     return 1 if $k eq $_;
  }
  return 0;
}

sub _is_flag{
  my $v = shift;
  if(not defined $v or $v eq '' or $v =~ /^0|1$/){
    return 1;
  }else{  
    return 0;
  }
}

sub _is_array{
  my $v = shift;
  if(ref $v eq 'ARRAY'){
    return 1;
  }else{
    return 0;
  }
}

sub _is_hash{
  my $v = shift;
  if(ref $v eq 'HASH'){
    return 1;
  }else{
    return 0;
  }
}

sub _is_string{
  my $v = shift;
  if(defined $v and ref $v eq ''){
    return 1;
  }else{
    return 0;
  }
}

sub _is_null{
  my $v = shift;
  return not defined $v; 
}

__END__
