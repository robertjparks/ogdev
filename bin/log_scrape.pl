#!/bin/perl
use strict;
use File::Find;

if($#ARGV<0){
	print "Scrapes liferay logs\n";
	print "usage 1: ./log_scrape.pl *.log\n";
	exit 0;
}
my @files=@ARGV;
my %at_count=();
my %at_ex=();
my %at_ex_last=();
foreach my $f (@files){
	my $ex='';
	my $at='';
	open (FH, "<$f")  || die "Can't open $f: $!\n";
	while(<FH>){
		my $ln=$_;
		if($ln=~m/ERROR \[.*Exception/){
			#print "GOT: ".$ln;
			$ex=$ln;
		}elsif($ex ne ''){
			if($ln=~m/^\s*at /){
				$at=$ln;
				if(!exists $at_count{$at}){
					#print "EX=$ex";
					#print "AT=$at";
					$at_count{$at}=1;
					$at_ex{$at}=$ex;
					$at_ex_last{$at}=$ex;
				}else{
					$at_count{$at}++;
					$at_ex_last{$at}=$ex;
				}
				$ex='';
				$at='';
			}
		}
	}
	close (FH);
	print "Done scraping file: $f!\n";
}

foreach my $f (@files){
	my $ex='';
	my $at='';
	open (FH, "<$f")  || die "Can't open $f: $!\n";
	while(<FH>){
		my $ln=$_;
		if($ln=~m/ERROR \[.*http/){
			#print "GOT: ".$ln;
			if($ln=~m/^.*\](.*)$/){
				$at="$1\n";
				$ex=$ln;
				#print "GOT: $1\n";
				if(!exists $at_count{$at}){
					#print "EX=$ex";
					#print "AT=$at";
					$at_count{$at}=1;
					$at_ex{$at}=$ex;
					$at_ex_last{$at}=$ex;
				}else{
					$at_count{$at}++;
					$at_ex_last{$at}=$ex;
				}
				$ex='';
				$at='';
			}else{
				die "unhandled line: $ln\n";
			}
		}
	}
	close (FH);
	print "Done scraping file: $f!\n";
}
#exit;

print "MAX TO MIN...........\n";
my @keys = sort { $at_count{$b} <=> $at_count{$a} } keys(%at_count);
foreach my $at (@keys){
	my $count=$at_count{$at};
	my $ex=$at_ex{$at};
	my $ex_last=$at_ex_last{$at};
	print "$count\n";
	print $ex;
	print $ex_last;
	print $at;
	print "\n";
}

