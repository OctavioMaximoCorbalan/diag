package DiagUtil;

use strict;
use warnings(FATAL=>'all');

our (@ISA, @EXPORT, @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(parse_xml_by_user);


sub filter_comments{
  my ($line, $is_comment) = @_;
  my $dq = 0; # dobule quote
  my $sq = 0; # single quote
  my @str = ();
  for(my $i = 0; $i<length($line); $i++){
    if($is_comment){
      if(substr($line, $i, 3) eq "-->"){
        $is_comment = 0;
        $i += 2;
      }
    }else{
      my $cur = substr($line, $i, 1);
      if($cur eq "\""){
          if(not $sq){
            $dq = $dq ? 0 : 1;
          } # else in sq, ignore dq
          push @str, $cur;
      }elsif($cur eq "\'"){
          if(not $dq){
            $sq = $sq ? 0 : 1;
          } #else in dq, ignore sq
          push @str, $cur;
      }elsif($cur eq "\\"){
          if($dq or $sq){
            push @str, substr($line, $i, 2);
            $i += 1;
          }else{
            push @str, $cur;
          }
      }elsif($cur eq "<"){ # test comment
          if(substr($line, $i, 4) eq "<!--"){
            if(not $dq and not $sq){
              $is_comment = 1;
            }else{
              push @str, substr($line, $i, 4);
            }
            $i += 3;
          }else{
            push @str, $cur;
          }
      }else{
          push @str, $cur;
      }
    }
  }
  $line = join "", @str;
  return ($line, $is_comment);
}

sub parse_xml_by_user{
  my $f = shift;
  my $tags_qr = qr/\b(TServerSuite|Test|Variation|Reference|Parameter|Template|Doc)\b/;
  open IN, "<$f" or die "Cannot open file $f to read. $!\n";
  my @ref_stack = ({});
  my $is_comment = 0;
  my $indent = 0;
  my @last_tag;
  my @cache;
  my $curtag = ""; # record current usefull tag
  local $_;
  while(<IN>){
    # pre processing
    my $line = $_;
    # 1. process comment
    ($line, $is_comment) = filter_comments($line, $is_comment);
    next if $line =~ /<\?xml/;
    # 2. match tag and content in a line
    if($line =~ /<[^<>]*$/ or (@cache and $line !~ />\s*$/)){ #not finished line
      push @cache, $line;
      next;
    }
    if(@cache){
      $line  = join '', @cache, $line;
      @cache = ();
    }
    #<Test id ="001" alt="uart_withinternal_loopback_wofc_wofifo" descrption="Uart Loopback Test case: 1" >
    while($line =~ /(<(\/?)([\w:\-]+)(.*?)(\/?)>)|([^<>]+)/sg){
      my ($preclose, $tagtype, $porperty, $postclose, $content) = ($2, $3, $4, $5, $6);
      my $match_str = $&;
      if($tagtype){
        push @last_tag, $tagtype if not $preclose; # push to tag stack
        if($tagtype =~ /$tags_qr/){
          $curtag = $tagtype;
          if(not $preclose and not $postclose){ # a new tag
            my $node = {tagtype=>$tagtype, rawdata=>$match_str, ptag=>$last_tag[-2]};
            push @ref_stack, $node;
            if($porperty){
              while($porperty =~ /([\w:\-]+)\s*=\s*"([^"]*)"/g){
                $node->{$1} = $2;
              }
            }
            $indent++;
          }elsif(not $preclose and $postclose){ #single item, no indent accumulate, add to top item directly
            my $node = {tagtype=>$tagtype, rawdata=>$match_str, ptag=>$last_tag[-2]};
            push @{$ref_stack[$#ref_stack]{$node->{tagtype}}}, $node;
            if($porperty){
              while($porperty =~ /(\w+)="(.*?)"/g){
                $node->{$1} = $2;
              }
            }
            $curtag = "";
          }elsif($preclose and not $postclose){ # close tag
            my $n = pop @ref_stack;
            $n->{rawdata} .= $match_str;
            push @{$ref_stack[$#ref_stack]{$n->{tagtype}}}, $n;
            $indent--;
            $curtag = "";
          }elsif($preclose and $postclose){
            die "Wrong tag";
          }
        }elsif($curtag eq "Doc"){
          $ref_stack[-1]{rawdata} .= $match_str;
        }
        pop @last_tag if $preclose or $postclose; # pop if it's a close tag
      }elsif(defined $content and $last_tag[-1] and $last_tag[-1] =~ /$tags_qr/ and $ref_stack[-1]{tagtype} = $last_tag[-1] or defined $content and $curtag eq "Doc"){ # if match the target tag, push content to value
        $ref_stack[-1]{value} = "" unless defined $ref_stack[-1]{value};
        $ref_stack[-1]{value} .= $content if $content =~ /\S/;
        $ref_stack[-1]{rawdata} .= $content if $curtag eq "Doc";
      }
    }
  }
  close IN;
  die "Unclosed tag in $f" if $indent;
  return $ref_stack[0];
}

1;
