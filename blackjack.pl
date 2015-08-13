use warnings;
use strict;

use Pod::Usage;
use Getopt::Long;

=head1 SYNOPSIS

blackjack.pl [options]

=head1 DESCRIPTION

A simple but sophisticated blackjack game. House rules: Dealer must hit to soft 17, blackjack pays 4:1.

This game uses a bunch of fancy unicode characters, if your terminal starts to act funny see the 
--disable-unicode option. If you are forced to use this option, try resizing your terminal until the
line that reads "Dealer hand:" is at the top. This will make it look like a refreshing screen as it does
with unicode support.

Use 'h' and 's' to hit or stand, alternatively use '+' or '.' to hit or stand respectively for easy playing from the numpad.

=head1 OPTIONS

 --disable-unicode, -d	Do not use unicode characters. The game will look a lot worse, 
			so try to use a different terminal or check your locale settings.

 --save-file, -s	Use this savefile instead of the default ~/.pbj


=head1 AUTHOR

Erik van den Bergh

=cut

my $DEBUG = 0;
my $showscores = 0;

my $playercash = 100;

# peanut butter jelly time! Or Perl BlackJack...
my $savefilepath = $ENV{"HOME"}."/.pbj";
my $no_unicode = 0;
my $help = 0;
my $man = 0;

GetOptions ("save-file=s" 	=> \$savefilepath,
            "disable-unicode" 	=> \$no_unicode,
	    "help"		=> \$help,
            "man"		=> \$man)
or die (pod2usage(1));

if ($help) {
  pod2usage(-verbose => 1,
            -msg     => "Try --man for a full description of options\n");
}

if ($man) {
  pod2usage(-verbose => 2);
}

# save file test for no permission
#my $savefilepath = "/usr/.pbj";

my $savefile;
if (-f $savefilepath) {
  open $savefile, $savefilepath;
  chomp($playercash = <$savefile>);
}

#player was kicked out for being broke
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

# carriage return character
my $cr="\x0D";

# card symbols Unicode
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

my $msg_speed = 0.5;

# Saves playercash to the savefile
sub save() {
  if ($savefile) {
    print $savefile "$playercash\n";
    seek($savefile, 0, 0);
  }
}

# Returns a newline and advances newline counter
# Why? Because we need to know how far back we need to go to refresh the screen
sub newline() {
  $newlines++; 
  return "\n";
}

# Gets player input and counts the newlines in it
sub getline() {
  my $c = <>;
  while ($c =~ m/\n/) {
    $newlines++;
    chomp($c);
  }
  return $c;
}

# Deals a card to a hand
# @param {array} - hand to deal card to
sub deal_card(\@) {

  # This makes it possible to card count, good luck geniuses
  if ($cards_dealt == 52) {
    print_state("Shuffling deck", $msg_speed);
    @deck = (0..51);
    $cards_dealt = 0;
  }

  my $card = splice(@deck, int(rand(scalar(@deck))), 1);
  push(@{$_[0]}, $card);
  $cards_dealt++;
}

# returns a string representation of a card (symbol and value)
# @param {int} - card to stringify
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
  if ($no_unicode) {
    my @syms = ("S", "C", "D", "H");
    $s .= $syms[$_[0] % 4]." ";
  } else {
    $s .= $symbols[$_[0] % 4]." "; 
  }
  return $s;
}

# initiates a new game: checks if player is broke, if not takes bet. Clears hands and deals new cards,
# printing after each dealt card.
sub new_game() {
  if ($playercash <= 0) {
    get_input("You're broke!");
    die("Game over!\n");
  }

  @cpuhand = ();
  @playerhand = ();
 
  changecash(-$bet);

  deal_card(@playerhand);
  print_state("Dealing cards...", $msg_speed);
  deal_card(@cpuhand);
  print_state("Dealing cards...", $msg_speed);
  deal_card(@playerhand);
  print_state("Dealing cards...", $msg_speed);
  deal_card(@cpuhand);
  print_state("Dealing cards...", $msg_speed);
  
  #aces test
  #push(@cpuhand, (0,1,2,3,6));
}

# This is some nifty unicode / shell stuff. It moves the cursor back the amount of newlines we
# have printed through newline(), prints empty lines to clear the screen, and moves the cursor back again
# so that we can print a new screen.
sub reset_screen() {
  if ($no_unicode) {
    return
  }
  # \033[xA is the unicode move cursor up character, where x is the amount of lines
  my $backlines =  "\033[$newlines"."A";
  print $backlines;

  # \033[2K is the clear line character, this loop clears the screen
  for (1..$newlines) { print "\033[2K\n"; }
  $newlines = 0;
  
  # move the cursor back again so we can start printing new stuff
  print $backlines;
}

# Print a message and wait for user input
# @param {String} - Message to print
sub get_input($) {
  print_state(shift,0);
  return getline();
}

# Print a message and continue after a timeout
# @param {String} - The message to print
# @param {float}  - Sleep timeout
sub print_state($$) {
  print_table();
  print shift.newline();

  if ($DEBUG) {
     print newline()."Cards dealt: $cards_dealt".newline();
     print "newlines = $newlines".newline();
  }

  else {
    select(undef,undef,undef,shift);
  }
}

# Print the game status: dealer hand, player's hand, the hand scores if that option is 
# set and finally the player's cash
sub print_table() {
  reset_screen();

  print "Dealer hand:".newline();

  for (my $i = 0; $i < scalar(@cpuhand); $i++) {
    # for the dealer we print a folded card and an open one while it is the players turn
    if ($i == 0 && $playerturn) {
      if ($no_unicode) {
        print "X ";
      } else { 
        print $cardback." ";
      }
  
    } else {
      print card_to_str($cpuhand[$i]);
    }
  }

  print newline();
  if ($showscores) {
    print "Dealer score: ".sum_cards(@cpuhand);
  }

  print newline()."Your hand:".newline();
  for my $card (@playerhand) { print card_to_str($card); }

  print newline();
  if ($showscores) {
    print "Your score: ".sum_cards(@playerhand);
  }
  print newline();

  print "Cash: \$$playercash";
  print newline();
}

# A testing method that prints the whole deck to check all card symbols and such
sub print_deck() {
  for my $card (@deck) { print int($card / 4) + 1; print $symbols[$card % 4]." "; }
  print "\n";
}

# Determine the hand score
# @param {Array} - the hand to sum
sub sum_cards(@){
  my $sum = 0;
  my $aces = 0;

  for my $card (@_) {
    my $cv = int($card / 4) + 1;
    # 10, J, Q and K are all 10
    if ($cv > 10) {
      $cv = 10;
    }

    # Aces are 11, see below for optional 1 value of ace
    if ($cv == 1) {
      $aces++;
      $cv = 11;
    }
    $sum += $cv;
  }

  #blackjack check, return special value if true
  if ($sum == 21 && scalar(@_) == 2 && $aces == 1 ) {
    return 99;
  } 
  
  # If the score is over 21 aces can be worth 1 to accomodate
  while ($sum > 21 && $aces > 0) {
    $sum -= 10;
    $aces--;
  }
  return $sum;
}

# Add or subtract a players cash and save
# @param {int} - amount to add or subtract (positive / negative)
sub changecash($) {
  $playercash += shift;
  save();
}

# Player has won by beating the dealer
sub player_win {
  my $prize = 2 * $bet;
  changecash($prize);
  get_input(shift."You win \$$prize!");
}

# Player has blackjack
sub player_bj {
  my $prize = 4 * $bet;
  changecash($prize);
  get_input("Blackjack! You win \$$prize!");
}

# Game is push
sub game_push() {
  # I have no idea why this is necessary, but otherwise the play area shifts down when the cpu stands
  # and the game resolves as push. ¯\_(ツ)_/¯
  if ($cpustand) {
    $newlines--;
    $cpustand = 0;
  }
  changecash($bet);
  get_input("Push.");
}

# Player lost is bust or dealer has more
sub player_lose {
  get_input(shift."Better luck next time!");
}

# Main game loop
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

  my $action = "";

  if ($firstgame && !$savefile) {
    get_input("Error writing to savefile: $saveerror. Your cash won't be saved. Press Enter to continue");
  }
  $firstgame = 0;

  # player turn
  while(1) {
    $action = get_input("(H)it or (S)tay?");

    # Hit
    if ($action eq "h" || $action eq "H" || $action eq "+") {
      deal_card(@playerhand);
    # Stay
    } elsif ( $action eq "s" || $action eq "S" || $action eq ".") {
      last;
    # No action could be determined
    } else {
      $action = print_state("Not sure what you want, try again?", 1.0);
    }
    
    # See if player is bust
    if (sum_cards(@playerhand) > 21) {
      print_table();
      $bust = 1;
      last;
    }
  } 
  
  $playerturn = 0;

  if (!$bust) {
    print_state("Dealer's turn", $msg_speed);

    # Cpu turn 
    while (1) {
      my $cpus = sum_cards(@cpuhand);

      # Cpu hits to soft 17, as in most casinos
      if ($cpus <= 16) {
        deal_card(@cpuhand);
        print_state("Dealer hits.", $msg_speed);
      } else {
        if ($cpus <= 21) {
          print_state("Dealer stands.", $msg_speed);
          $cpustand = 1;
          $newlines++;
        }
        last;
      }
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
