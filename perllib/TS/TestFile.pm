package TS::TestFile;

use strict;

our $AUTOLOAD;

my %attr  = (name=>'',actions=>[], param=>[]);

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
  $self->{param} ||= [];
  $self->{actions} ||= [];
  return $self;
}

sub clone{
  my $self = shift;
  my $new = new TS::TestFile(
    name=>$self->name, 
    param=>[@{$self->param}], # redefine param
    actions=>$self->actions  # reuse actions
  );
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

sub get_cmd{
  return "In TS::TestFile: To do function";
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