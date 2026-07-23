package TS::Universe;

use strict;
use Data::Dumper;
use TS::Param;

# This module provide configuration and runtime environment values

our $AUTOLOAD;
our $Config = {
  params=>{},
  blocks=>{},
  funcs=>{},
  log => {
    export=>"tserver.log",
    type=>"yaml",
    file=>"log.yml",
  }
};
our $Env = {
  action_queue => [],
  current_test_param => '',
};

# cmd param list
our @arg_format = (
  "test=s", "tf=s", "block|blk=s", "func=s", "ip=s", "seqfile=s", #execute options
  "export:s", "clearlog", "dryrun",  # log options
  "scriptloop|sl=i", 
  "showblock:s", "showtest:s", "tclist", "filter=s", "expand", # query options
  "suitemargin=s", "nogb", "nobaco", "nobamaco", "defstate=s", "nodefstate", "nosetstate", # margin options
  "noctf", "defaultcf", "notoolrc","nousb","skipgen4","gen4","usb","xgmidump","usb", "loopdiff=i",
  "mcchannel=s","secure",
  "logtype=s", "logfile=s","lfb", 
  "report=s","maxfan",
  "external_build", "rmdriver",
  "tid");

our $params = {}; # params defination in obj mode

sub new{
  my $class=shift;
  my $self = {};
  bless $self, $class;
}

sub Config{
  return $Config;
}

sub Env{
  return $Env;
}

# deal with params
sub get_arg_format{
  return @arg_format;
}

sub add_param{
  my $param = shift;
  push @arg_format, $param->to_arg_format();
}

sub set_device_class{
  my $self = shift;
  $Env->{device_class} = shift;
}
sub get_device_class{
  return $Env->{device_class};
}

sub set_suite_type{
  my $self = shift;
  $Env->{suite_type} = shift;
}
sub get_suite_type{
  return $Env->{suite_type};
}

sub set_const{
  my $self = shift;
  my $name = shift;
  my $val = shift;
  $Env->{const}{$name} = $val; 
}

sub get_const{
  my $self = shift;
  my $name = shift;
  return $Env->{const}{$name};
}


####

sub CheckArgs{

}

1;
__END__
