#!/bin/perl
use Cwd;
use File::Copy;
use File::Basename;
use strict;
use Data::Dumper;

# globals
my @host_types=("ogapp","ogsbl","ogsoa","ogdb","ogopa");
my $known_hosts_dir="D:\\ogdev\\known_hosts";
my $known_conf_dir='D:\ogdev\tomcat\conf\Catalina\localhost';
my $webapps_dir='D:\liferay-portal-6.1.1-ce-ga2\tomcat-7.0.27\webapps';
my $tomcat_deploy_dir='D:\liferay-portal-6.1.1-ce-ga2\deploy';
my $tomcat_conf_dir='D:\liferay-portal-6.1.1-ce-ga2\tomcat-7.0.27\conf\Catalina\localhost';

if($#ARGV<0){
	print "Updates the hosts file based on a passed server using naming conventions\n";
	print "Updates the tomcat config files with appropriate passwords for the env\n";
	print "usage 1: ./update_hosts.pl dev2\n";
	print "usage 2: ./update_hosts.pl test1\n";
	print "usage 3: ./update_hosts.pl ogapp3.3.2.2hftest.og.devexeter.com\n";
	print "usage 4: ./update_hosts.pl ogdb3.3.2.2hftest.og.devexeter.com\n";
	print "usage 5: ./update_hosts.pl http://ogapp3.3.2.6egpr3.og.devexeter.com:7004\n";
	print "Pretty much any server name ogapp, ogdb, or valid URL will work\n";
	exit 0;
}
my $name=$ARGV[0];


# Strip URL down to server name if passed
$name=cleanup_host_name($name);
print "Updating hosts based on [$name]\n";

# Since we are going to update the hosts file we need
# to flush the dns so the host file has a good shot of 
# getting picked up.

my $is_aws=is_aws_name($name);
my %hosts=();

if($is_aws){
	%hosts=get_hosts_from_nslookup($name);
}else{
	my $known_host_file=get_known_hosts_file($name);
	if($known_host_file eq ''){
		die "This [$name] does not match aws convention and is not a known host:".join(',',get_known_hosts())."\n";
	}
	%hosts=get_hosts_from_file($known_host_file);
}

print Dumper(\%hosts);
#print join(',',get_known_hosts());

# Update the tomcat configuration files
update_tomcat_conf($is_aws?'aws':$name);

# Update the windows hosts file
update_windows_hosts(\%hosts);


########################### SUBROUTINES ##########################

sub flush_dns(){
	print `ipconfig /flushdns`;
}

# Given a hosts hash, update the windows hosts file
sub update_windows_hosts(\%){
	my $hosts_ref=shift;
	my %hosts=%$hosts_ref;
	#print Dumper(\%hosts);
        my $win_newline = "\015\012";
	# backup and update hosts file
	my $hosts_file='C:\Windows\System32\drivers\etc\hosts';
	my $hosts_backup='C:\Windows\System32\drivers\etc\hosts.bak';
	copy($hosts_file,$hosts_backup) or die "Copy failed: $!";
	print "Created backup host file: $hosts_backup\n";
	open (FH, "<$hosts_backup")  || die "Can't open $hosts_backup: $!\n";
	open (OUT, ">$hosts_file")  || die "Can't open $hosts_file: $!\n";
	# keep original host file but skip out host types
	while(<FH>){
		my $ln=$_;
		my @parts=split /\s+/, $ln;
		#print "parts=" .  (join '|', @parts ) . "\n";
		if($#parts >= 1 and exists $hosts{$parts[1]}){
			#print "SKIP EXISTING: ".$ln;
			next;
		}
		#print "KEEP EXISTING: ".$ln;
		print OUT $ln;
	}
	# append our new hosts
	foreach my $k (keys %hosts){
		print OUT "$hosts{$k}" . $win_newline;
	}
	close (FH);
	close (OUT);
	print "Done updating host file: $hosts_file!\n";
}

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

sub update_tomcat_conf($){
	my $name=shift;
	my $root_file=$known_conf_dir ."\\ROOT." . $name . ".xml";
	if(not -e $root_file){
		die "cannot find appropriate tomcat password file [$root_file]\n";
	}
	# loop thru existing conf files and overwrite them
	# loop thru any deploy dir wars and create conf for them
	# loop thru any webapps and create conf for them
	my @all_webapp_files=(
		get_tomcat_deploy_wars(),
		get_tomcat_webapps(),
		get_tomcat_conf_files()
	);
	my %conf_files=();
	foreach my $f (@all_webapp_files){
		my($filename, $dir, $suffix)=fileparse($f, qr/\.[^.]*/);
		#print "f=[$f] filename=$filename,dir=$dir,suffix=$suffix\n";
		my $conf_name=$filename . '.xml';
		$conf_files{$conf_name}=1;
	}
	foreach my $conf_file (keys %conf_files){
		print "$conf_file\n";
		my $conf_path=$tomcat_conf_dir . "\\" . $conf_file;
		print "cp $root_file $conf_path\n";
		copy($root_file,$conf_path) or die "Copy failed: $!";
	}
}

# return any existing tomcat conf files
sub get_tomcat_conf_files(){
	my @array=();
	foreach my $war (grep /\.xml$/,get_files($tomcat_conf_dir)){
		#print "found xml=$war\n";
		push @array,$war;
	}
	return @array;
}

# return any pending tomcat deploy wars
sub get_tomcat_deploy_wars(){
	my @array=();
	foreach my $war (grep /\.war$/,get_files($tomcat_deploy_dir)){
		#print "found war=$war\n";
		push @array,$war;
	}
	return @array;
}

# return tomcat webapps sub dirs
sub get_tomcat_webapps(){
	my @array=();
	foreach my $webapp (get_sub_directories($webapps_dir)){
		#print "found webapp=$webapp\n";
		push @array,$webapp;
	}
	return @array;
}

# return the files under the passed directory
sub get_files($){
	my $dir=shift;
	chdir($dir) or die "cannot find dir [$dir]: $!";
	my @array = grep -f, map { Cwd::abs_path($_) } glob "*";
	return @array; 
}

# return sub directories of passed directory
sub get_sub_directories($){
	my $dir=shift;
	chdir($dir) or die "cannot find dir [$dir]: $!";
	my @array = grep -d, map { Cwd::abs_path($_) } glob "*";
	return @array;
}


# Update the tomcat config files with the correct passwords
# our aws machines have username=password for db logins
# out colo machines have username=password12345 for db logins
sub update_tomcat($){
	my $is_aws=shift;
	$is_aws=1;
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


# Builds the hosts hash by inferring host names from the
# passed hostname and then doing an nslookup
sub get_hosts_from_nslookup($){
	my $host_name=shift;
	my $host_suffix=get_aws_host_suffix($host_name);
	my %hosts=();
	foreach my $host_type (@host_types){
		my $derived_name=$host_type . $host_suffix;
		#print "derived_name [$derived_name]\n";
		my $addr=nslookup($derived_name);
		#print "addr=[$addr]\n";
		#print "nslookup $derived_name $addr\n";
		my $og="$host_type";
		my $ogdev="$host_type"."dev";
		my $ogtest="$host_type"."test";
		$hosts{$og}="$addr\t$og\t$ogdev\t$ogtest";
	}
	return %hosts;
}

# Builds the hosts hash by grepping the passed hosts file
sub get_hosts_from_file($){
	my $file=shift;
	my %hosts=();
	print "Reading host file: $file!\n";
	open (FH, "<$file")  || die die "get_hosts_hash_via_file can't open file $file: $!\n";
	while(<FH>){
		my $ln=$_;
		$ln=~s/\r?\n//g;
		foreach my $host_type (@host_types){
			if($ln=~m/^[0-9]+.*$host_type.*/){
				$hosts{$host_type}=$ln;
				next;
			}else{
			}
		}
	}
	close (FH);
	return %hosts;
}

# Takes in a hostname that might be a url and returns the pure domain name
sub cleanup_host_name($){
	my $name=shift;
	$name=~s/http:\/\///g;
	$name=~s/:.*$//g;
	return $name;
}

# Return 1 if passed name matches aws convention
sub is_aws_name($){
	my $name=shift;
	foreach my $host_type (@host_types){
		if($name=~m/^$host_type/){
			return 1;
		}
	}
	return '';
}

# Given an aws host name like ogapp.blah return '.blah'
sub get_aws_host_suffix($){
	my $name=shift;
	foreach my $host_type (@host_types){
		if($name=~m/^$host_type/){
			return substr $name, length($host_type);
		}
	}
	die "Error in get_aws_host_suffix [$name] didn't match an aws host type\n";
}

# returns "" host is not known, else returns path to host file.
sub get_known_hosts_file($){
	my $name=shift;
	my $hosts_file=$known_hosts_dir."\\hosts.".$name;
	print "looking for file:$hosts_file\n";
	if(-e $hosts_file){
		return $hosts_file;
	}
	return '';
}

# return the list of known hosts
sub get_known_hosts(){
	my @known_hosts=();	
	chdir($known_hosts_dir) or die "$!";
	my @files =glob "*";
	foreach my $f (@files){
		if($f=~m/hosts.(.+)$/){
			my $host_name=$1;
			#print "$host_name\n";
			push @known_hosts,$host_name;
		}else{
			#print "unexpected file: $f\n";
		}
	}
	return @known_hosts;
}
