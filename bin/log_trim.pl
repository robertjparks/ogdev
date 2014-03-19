#!/bin/perl
use strict;
use File::Find;

if($#ARGV<0){
	print "Trims liferay logs of known errors\n";
	print "usage 1: ./log_trim.pl *.log\n";
	exit 0;
}
my @files=@ARGV;
my %at_count=();
my %at_ex=();
foreach my $f (@files){
	my $ex='';
	my $at='';
	my $counter = 0;
	open (FH, "<$f")  || die "Can't open $f: $!\n";
	while(<FH>){
		my $ln=$_;
		if($ln=~m/\] com\.liferay\.portal\.NoSuchUserException\:/){
			$counter = 62;
		}
		if($ln=~m/ERRORED RATED PLAN:/){
			$counter = 1;
		}
		if($ln=~m/ERROR=RateBand lookup/){
			$counter = 1;
		}
		if($ln=~m/ERROR=Plan requires primary/){
			$counter = 1;
		}
		if($ln=~m/RateBand lookup failed for plan/){
			$counter = 1;
		}
		if($ln=~m/ProviderSearchController:114] view - viewResult/){
			$counter = 1;
		}
		if($ln=~m/ProviderSearchController:114] searchProvider criteria/){
			$counter = 1;
		}
		if($ln=~m/SiebelProviderSearchServiceImpl:114] findProviders -/){
			$counter = 1;
		}
		if($ln=~m/ProviderSearchController:114] Provider Search/){
			$counter = 1;
		}
		if($ln=~m/Unable to import user cn=/){
			$counter = 35;
		}

		
		if($counter < 1){
			print $ln;
		}
		$counter = $counter - 1;
	}
	close (FH);
	print "Done trimming file: $f!\n";
}

