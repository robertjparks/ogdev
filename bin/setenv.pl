#!/bin/perl
use File::Copy;
use strict;

if($#ARGV<0){
	print "Updates the hosts file based on a passed server using naming conventions\n";
	print "Updates the tomcat config files with appropriate passwords for the env\n";
	print "usage 1: ./update_hosts.pl dev\n";
	print "usage 2: ./update_hosts.pl test\n";
	print "usage 3: ./update_hosts.pl ogapp3.3.2.2hftest.og.devexeter.com\n";
	print "usage 4: ./update_hosts.pl ogdb3.3.2.2hftest.og.devexeter.com\n";
	print "usage 5: ./update_hosts.pl http://ogapp3.3.2.6egpr3.og.devexeter.com:7004\n";
	print "Pretty much any server name ogapp, ogdb, or valid URL will work\n";
	exit 0;
}
my $name=$ARGV[0];

# Strip URL down to server name if passed
$name=~s/http:\/\///g;
$name=~s/:.*$//g;
print "Updating hosts based on [$name]\n";



# Since we are going to update the hosts file we need
# to flush the dns so the host file has a good shot of 
# getting picked up.
print `ipconfig /flushdns`;


my $is_aws=1;
my $var="";
if($name eq 'dev' or $name eq 'test'){
	$is_aws=0;
} elsif($name=~m/^og(...?)/){
	#print "got [$1]\n";
	$var=$1;
	if($var=~m/db/){
		$var='db';
	}
}else{
	print "no match\n";
	exit 1;
}

update_tomcat($is_aws);

my %hosts=();
my @vars=("app","sbl","soa","db","opa");

# hard code dev and test because there are no domain names 
# for them.
if(lc($name) eq 'dev'){
	$hosts{ogapp}="172.10.10.126\togapp\togappdev\togapptest";
	$hosts{ogopa}="172.10.10.124\togopa\togopadev\togopatest";
	$hosts{ogsoa}="172.10.10.123\togsoa\togsoadev\togsoatest";
	$hosts{ogsbl}="172.10.10.125\togsbl\togsbldev\togsbltest";
	$hosts{ogdb}="172.10.10.122\togdb\togdbdev\togdbtest";
}
elsif(lc($name) eq 'test'){
	$hosts{ogapp}="172.10.10.135\togapp\togappdev\togapptest";
	$hosts{ogopa}="172.10.10.134\togopa\togopadev\togopatest";
	$hosts{ogsoa}="172.10.10.132\togsoa\togsoadev\togsoatest";
	$hosts{ogsbl}="172.10.10.149\togsbl\togsbldev\togsbltest";
	$hosts{ogdb}="172.10.10.136\togdb\togdbdev\togdbtest";
}else{
	foreach my $v (@vars){
		my $new=$name;
		$new=~s/$var/$v/;
		#print "new [$new]\n";
		my $addr=nslookup($new);
		#print "addr=[$addr]\n";
		#print "nslookup $new $addr\n";
		my $og="og$v";
		my $ogdev="og$v"."dev";
		my $ogtest="og$v"."test";
		$hosts{$og}="$addr\t$og\t$ogdev\t$ogtest";
	}
}


# backup and update hosts file
my $hosts_file='C:\Windows\System32\drivers\etc\hosts';
my $hosts_backup='C:\Windows\System32\drivers\etc\hosts.bak';
copy($hosts_file,$hosts_backup) or die "Copy failed: $!";
print "Created backup host file: $hosts_backup\n";
open (FH, "<$hosts_backup")  || die "Can't open $hosts_backup: $!\n";
open (OUT, ">$hosts_file")  || die "Can't open $hosts_file: $!\n";
while(<FH>){
	my $ln=$_;
	my $update_flag=0;
	foreach my $k (keys %hosts){
		if($ln=~m/^[0-9]+.*$k.*/){
			print "UPDATED: ".$ln;
			print "TO THIS: $hosts{$k}\n";
			print OUT "$hosts{$k}\n";
			$update_flag=1;
			next;
		}
	}
	if(!$update_flag){
		print OUT $ln;
	}
}
close (FH);
close (OUT);
print "Done updating host file: $hosts_file!\n";



# given a host name lookup the IPADDRESS
sub nslookup($){
	 my $n=shift;
	 my $addr="";
	 my $output=`nslookup $n 2>&1`;
	 #print "OUT=$output\n";
	 foreach my $line (split /[\r\n]+/, $output) {
	 	my @parts=split /:/,$line;
	 	if($#parts==1){
			#print "part0=$parts[0]\n";
			#print "part1=$parts[1]\n";
			if($parts[0] =~ m/Address.*/){
				if($parts[1]=~m/\s*(\d+\.\d+\.\d+\.\d+)\s*/){
					$addr=$1;
					#print "addr=[$addr]\n";
				}else{
					#print "NO MATCH2: $parts[1]\n";
				}
			}else{
				#print "NO MATCH1: $parts[0]\n";
			}
	 	}else{
			#print "parts.size=".scalar(@parts)."\n";
		}
	 }
	 if($addr eq ""){
	 	die "could not do nslookup for [$n]\n";
	 }

	 $addr =~ s/^\s+|\s+$//g ;
	 $addr =~ s/^\s+|\s+$//g ;
	 return $addr;
}


# Update the tomcat config files with the correct passwords
# our aws machines have username=password for db logins
# out colo machines have username=password12345 for db logins
sub update_tomcat($){
	my $is_aws=shift;
	# foreach file in D:\liferay-portal-6.1.1-ce-ga2\tomcat-7.0.27\conf\Catalina\localhost\*.xml
	# if (aws) set pw=username else set pw=username12345
	my $dir='D:\liferay-portal-6.1.1-ce-ga2\tomcat-7.0.27\conf\Catalina\localhost';
	print "Checking passwords based on is_aws=[$is_aws] in:$dir\n";
	chdir($dir) or die "$!";
	my @files = glob "*.xml";
	foreach my $f (@files) {
    		print "Checking password file:$f\n";
		open (FH, "<$f")  || die "Can't open $f: $!\n";
		my $changed_file="";
		my $changed=0;
		while(<FH>){
			my $ln=$_;
			if($ln=~m/username\s*=\s*["'](.+?)["']/){
				my $username=$1;
				my $password=$is_aws ? $username : ($username . "12345");
				if(m/(^.*password\s*=\s*["'])(.+?)(["'].*)/){
					my $orig_password=$2;
					if($password ne $orig_password){
						# do it this way so we dont change the orig newline chars
						$ln=~s/(^.*password\s*=\s*["'])(.+?)(["'].*)/$1$password$3/;
						$changed=1;
					}
				}

			}
			$changed_file .= $ln;
		}
		close FH;
		if($changed){
			print "Updating file: $f\n";
			open (OUT, ">$f")  || die "Can't open $f: $!\n";
			print OUT $changed_file;
			#print "$changed_file";
			close (OUT);
		}

	}
}

