use warnings;
use strict;

#################################################
#						#
#		   MoSCoW			#
#						#
# TODO M:					#
#         					#
# TODO S:					#
#         - Comments				#
#         - Docs				#
#	  - Change bet				#
#	  - Game state object			#
# TODO C:					#
#	  - Player rebuy message		#
#						#
# TODO W: 					#
#         - ASCII welcome screen		#
#						#
#################################################

my $DEBUG = 0;
my $showscores = 0;

my $playercash = 100;

# peanut butter jelly time! Or Perl BlackJack...
my $savefilepath = $ENV{"HOME"}."/.pbj";

# save file test for no permission
#my $savefilepath = "/usr/.pbj";

my $savefile;
if (-f $savefilepath) {
  open $savefile, $savefilepath;
  chomp($playercash = <$savefile>);
}

if ($playercash == 0) {
  $playercash = 100;
}

open $savefile, ">", $savefilepath or $savefile = 0;
my $saveerror = $!;

my $dlog;
if ($DEBUG) {
  open $dlog, ">", "bj.log" or die $!;
  select $dlog;
  $| = 1;
  select STDERR;
  print $dlog "test\n";
}

my $cpustand = 0;

print "\n\n";

my $firstgame = 1;
my $cards_dealt = 0;
my $newlines = 0;
my $bet = 5;

my $cr="\x0D";
my $spade="\xE2\x99\xA0";
my $club="\xE2\x99\xA3";
my $diamond="\xE2\x99\xA6";
my $heart="\xE2\x99\xA5";
my $cardback="\xF0\x9F\x82\xA0";

my @symbols=($spade, $club, $diamond, $heart);

my @deck = (0..51);

my @cpuhand;
my @playerhand;

my $playerturn = 0;

sub save {
  if ($savefile) {
    print $savefile "$playercash\n";
    seek($savefile, 0, 0);
  }
}
sub newline() {
  $newlines++; return "\n";
}

sub getline() {
  my $c = <>;
  while ($c =~ m/\n/) {
    $newlines++;
    chomp($c);
  }
  return $c;
}

sub deal_card(\@) {

  if ($cards_dealt == 52) {
#    if ($DEBUG) {
      print_state("Shuffling deck");
#    }
    @deck = (0..51);
    $cards_dealt = 0;
    
  }

  my $card = splice(@deck, int(rand(scalar(@deck))), 1);
  push(@{$_[0]}, $card);
  $cards_dealt++;
}

sub card_to_str($) {
  my $s = "";
  my $cardval = int($_[0] / 4) + 1;

  if ($cardval == 11) {
    $s .= "J";
  } elsif ($cardval == 12) {
    $s .= "Q";
  } elsif ($cardval == 13) {
    $s .= "K";
  } elsif ($cardval == 1) {
    $s .= "A";
  } else { 
    $s .= $cardval;
  }
  $s .= $symbols[$_[0] % 4]." "; 
  return $s;
}

sub new_game() {
  if ($playercash <= 0) {
    print_state("You're broke!", 1);
    die("Game over!\n");
  }
  @cpuhand = ();
  @playerhand = ();
 
  changecash(-$bet);

  deal_card(@playerhand);
  print_state("Dealing cards...");
  deal_card(@cpuhand);
  print_state("Dealing cards...");
  deal_card(@playerhand);
  print_state("Dealing cards...");
  deal_card(@cpuhand);
  print_state("Dealing cards...");
  
  #aces test
  #push(@cpuhand, (0,1,2,3, 6));
}
sub reset_screen {
  my $backlines =  "\033[$newlines"."A";
  print $backlines;
  for (1..$newlines) { print "\033[2K\n"; }
  $newlines = 0;
  print $backlines;
}

sub print_state {
  print_table();
  print shift.newline();

  if ($DEBUG) {
     print newline()."Cards dealt: $cards_dealt".newline();
     print "newlines = $newlines".newline();
  }

  if (shift) { 
    return getline();
  } else {
    select(undef,undef,undef,0.5);
  }

}

sub print_table() {
  reset_screen();
  print "Dealer hand:".newline();
  for (my $i = 0; $i < scalar(@cpuhand); $i++) {
    if ($i == 0 && $playerturn) {
      print $cardback." ";
    } else {
      print card_to_str($cpuhand[$i]);
    }
  }
  print newline();
  if ($showscores) {
    print "Dealer score: ".sum_cards(@cpuhand);
  }
  print newline()."Your hand:".newline();
  for my $card (@playerhand) { print card_to_str($card) };
  print newline();
  if ($showscores) {
    print "Your score: ".sum_cards(@playerhand);
  }
  print newline();
  print "Cash: \$$playercash";
  print newline();
}

sub print_deck() {
  for my $card (@deck) { print int($card / 4) + 1; print $symbols[$card % 4]." "; }
  print "\n";
}

sub sum_cards(@){
  my $sum = 0;
  my $aces = 0;
  for my $card (@_) {
    my $cv = int($card / 4) + 1;
    if ($cv > 10) {
      $cv = 10;
    }
    if ($cv == 1) {
      $aces++;
      $cv = 11;
    }
    $sum += $cv;
  }

  #blackjack check
  if ($sum == 21 && scalar(@_) == 2 && $aces == 1 ) {
    return 99;
  } 
  
  while ($sum > 21 && $aces > 0) {
    $sum -= 10;
    $aces--;
  }
  return $sum;
}

sub changecash {
  $playercash += shift;
  save();
}

sub player_win {
  my $prize = 2 * $bet;
  changecash($prize);
  print_state(shift."You win \$$prize!", 1);
}

sub player_bj {
  my $prize = 4 * $bet;
  changecash($prize);
  print_state("Blackjack! You win \$$prize!", 1);
}

sub game_push() {
  # I have no idea why this is necessary, but otherwise the play area shifts down when the cpu stands
  # and the game resolves as push. ¯\_(ツ)_/¯
  if ($cpustand) {
    $newlines--;
    $cpustand = 0;
  }
  changecash($bet);
  print_state("Push.", 1);
}

sub player_lose {
  if ($DEBUG) {
    print $dlog "player_lose, newlines: $newlines\n";
  }
  print_state(shift."Better luck next time!", 1);
}

#print_deck();

while(1) {
  $playerturn = 1;
  new_game();
  my $bust = 0;

  if (sum_cards(@playerhand) == 99) {
    $playerturn = 0;
    player_bj();
    next;
  }

  if (sum_cards(@cpuhand) == 99) {
    $playerturn = 0;
    player_lose("Dealer has blackjack! ");
    next;
  }

  # players turn
  my $action = "";

  if ($firstgame && !$savefile) {
    print_state("Error writing to savefile: $saveerror. Your cash won't be saved. Press Enter to continue", 1);
  }
  $firstgame = 0;

  while(1) {
    $action = print_state("(H)it or (S)tay?", 1);
    if ($action eq "h" || $action eq "H" || $action eq "+") {
      deal_card(@playerhand);
    } elsif ( $action eq "s" || $action eq "S" || $action eq ".") {
      last;
    } else {
      $action = print_state("Not sure what you want, try again?");
    }
    
    if (sum_cards(@playerhand) > 21) {
      print_table();
      $bust = 1;
      last;
    }
  } 
  
  # cpu turn 
  $playerturn = 0;
  if (!$bust) {
    print_state("Dealer's turn");
    while (1) {
      my $cpus = sum_cards(@cpuhand);
      if ($cpus <= 16) {
        deal_card(@cpuhand);
        print_state("Dealer hits.");
      } else {
        if ($cpus <= 21) {
          print_state("Dealer stands.");
          $cpustand = 1;
          $newlines++;
        }
        last;
      }
#      select(undef,undef,undef,0.2);
    }
  } 

  if (!$bust) {
    my $ps   = sum_cards(@playerhand);
    my $cpus = sum_cards(@cpuhand);

    if ($cpus > 21) {
      player_win("Dealer bust! ");
    } elsif ($cpus > $ps) {
      player_lose();
    } elsif ($cpus == $ps) {
      game_push();
    } else {
      player_win();
    }
  } else {
    player_lose("Bust! ");
  }
}
