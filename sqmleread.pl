#!/usr/bin/perl
# commande de lecture simple perl: sqmleread.pl 192.168.0.206 10001 1
# il faut remplacer l'adresse ip par l'adresse attribuee au sqm
#
use IO::Socket;

if ($#ARGV == -1 ) {
  print STDERR "Usage: ./socket.pl sqm_le_addr sqm_le_port n_readings\n";
  print STDERR "       ./socket.pl unihedron.dyndns.org 10001 10\n";
  exit;
}

if (! defined($ARGV[0])) {
  print STDERR "The address or IP of the SQM-LE is required\n";
  exit;
} else {
  $sqm_le_addr = $ARGV[0];
}

if (! defined($ARGV[1])) {
  print STDERR "Port number not provided so 10001 assumed\n";
  $sqm_le_port = 10001;
} else {
  $sqm_le_port = $ARGV[1];
}

if (! defined($ARGV[2])) {
  print STDERR "Number of readings not provided so 10 assumed\n";
  $n_readings = 10;
} else {
  $n_readings = $ARGV[2];
}

$sleep_sec = 1;

$remote = IO::Socket::INET->new(PeerAddr => $sqm_le_addr,
 	                        PeerPort => $sqm_le_port,
                                Proto    => 'tcp') 
  || die("Cannot connect to port $sqm_le_port on $sqm_le_addr:$!");

$remote->autoflush(1);
# print STDERR "[Connected to $sqm_le_addr:$sqm_le_port]\n";

for $count (1..$n_readings) {

  #-- Delay between readings
  sleep($sleep_sec);

  #-- Initialize response string
  $str="";

  #-- Send request to remote SQM
  print $remote "rx";

  #-- Add response to string
  $str .= <$remote>;

  #-- If newline, print string and start next count
  if ($str =~ /\n/) {
    print $str;
    next;
  }
}

#-- Close remote socket
$remote->close;