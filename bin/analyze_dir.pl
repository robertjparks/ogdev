#!/bin/perl
use strict;
use File::Find;

sub loadFiles(); #udf
sub mySub(); #udf
my @files = ();
my $dir = shift ||"gitrunk";#|| die "Argument missing: directory name\n";
loadFiles(); #call

my %extSum=();
my %extCount=();
my %extExample=();
foreach my $f (@files){
	my ($ext) = $f =~ /(\.[^.]+)$/;
	my $size=-s $f;
	#print "$f--$ext--$size\n";
	if(exists $extSum{$ext}){
		$extSum{$ext}+=$size;
		$extCount{$ext}++;
	}else{
		$extSum{$ext}=$size;
		$extCount{$ext}=1;
		$extExample{$ext}=$f;
	}
}
print "extension,bytes,count,example\n";
foreach my $ext (sort { $extSum{$a} <=> $extSum{$b} }keys %extSum){
	print "$ext,$extSum{$ext},$extCount{$ext},$extExample{$ext}\n";

}


sub loadFiles()
{
  find(\&mySub,"$dir"); #custom subroutine find, parse $dir
}

# following gets called recursively for each file in $dir, check $_ to see if you want the file!
sub mySub()
{
  push @files, $File::Find::name if not -d;
}
