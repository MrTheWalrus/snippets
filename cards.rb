# Draw an arbitrary number of cards from a standard deck and 
# print out the best 5-card poker hand possible from those cards.
# Optionally, two (wild card) Jokers can be included.
# Modifying the deck away from standard should not produce any issues,
# but more than two jokers may produce some unusual behavior.

# Originally invented for use with the 
# Deadlands Classic RPG (http://www.peginc.com/product-category/deadlands/),
# which uses this card draw mechanic in a number of places.

# This code is (c) 2014 Ian McLean, and is
# released under the WTFPL (http://www.wtfpl.net/), so do whatever
# you want with it.

# Usage:
# Open a ruby console, such as irb or pry
# load this file (load './cards.rb')
# d = Deck.new(:jokers=>true)
# d.shuffle
# d.draw(number_of_cards)

# Prevent already-defined constant error on reloading
Object.send(:remove_const, :Card) if defined?(Card)
class Card
  SUITS = ['Clubs', 'Diamonds', 'Hearts', 'Spades']
  RANK_ORDER = [2, 3, 4, 5, 6, 7, 8, 9, 10, 'Jack', 'Queen', 'King', 'Ace']
  attr_reader :rank, :suit
  attr_writer :rank, :suit

  def to_s(format = nil)
    if rank == 'Joker'
      if format == :short
        "Jk(#{suit.first.upcase})"
      else
        "#{suit} #{rank}"
      end
    else
      if format == :short
        "#{rank}#{suit.first}"
      else
        "#{rank} of #{suit}"
      end
    end
  end

  def joker?
    rank == 'Joker'
  end

  def value
    RANK_ORDER.index(rank)
  end

  def suit_value
    if rank == 'Joker'
      4
    else
      SUITS.index(suit) + 1
    end
  end
end

class Deck
  attr_reader :cards, :drawn
  attr_writer :cards, :drawn

  def fill(args = {})
    Card::SUITS.each do |s|
      Card::RANK_ORDER.each do |r|
        c = Card.new
        c.rank = r
        c.suit = s
        cards << c
      end
    end
    if args[:jokers]
      ['Red', 'Black'].each do |s|
        c = Card.new
        c.rank = 'Joker'
        c.suit = s
        cards << c
      end
    end
  end

  def initialize(args = {})
    self.cards = []
    self.drawn = []
    fill(args)
    true
  end

  def shuffle(return_discards = true)
    self.return_discards
    self.cards = self.cards.sort_by{rand}
    true
  end

  def return_discards
    self.cards = (self.cards + self.drawn)
    self.drawn = []
  end

  def draw(hand)
    if self.cards.size < hand
      puts "Deck only contains #{self.cards.size} cards. Reshuffling."
      self.shuffle
    end
    pulled = self.cards[0..hand-1]
    pulled.sort_by!{|c| Card::RANK_ORDER.index(c.rank) || 14}
    self.cards = self.cards[hand..-1]
    self.drawn = self.drawn + pulled
    puts Hand.best(pulled)

    pulled
  end

end

class Hand
  class << self

    def best(cards)
      Hand.straight_flush?(cards) || 
        Hand.four?(cards) || 
        Hand.full_house?(cards) ||
        Hand.flush?(cards) ||
        Hand.straight?(cards) ||
        Hand.three?(cards) ||
        Hand.two_pair?(cards) ||
        Hand.pair?(cards) ||
        Hand.nothing
    end
    def nothing
      'Nothing!'
    end

    def straight_flush?(cards)
      fsuits = cards.reject{|c| c.joker?}.group_by{|c| c.suit}.select do |s, cs| 
        (cs.size + cards.select{|c| c.joker?}.size) >= 5 
      end

      fsuits.select! do |s, cs|
        # clever!
        straight?(cs)
      end

      best_sf = fsuits.sort_by do |s, cs|
        high_card = straight?(cs).match(/\w+/).to_s
        Card::RANK_ORDER.index(high_card.to_i == 0 ? high_card : high_card.to_i) + 
          (Card::SUITS.index(s) * 0.1)
      end.last
      if best_sf
        royal = true
        jokers_left = cards.select{|c| c.joker?}.size
        [10,'Jack','Queen', 'King', 'Ace'].each do |r|
          if best_sf[1].any?{|c| c.rank == r}
          elsif jokers_left > 0
            jokers_left -= 1 
          else
            royal = false
          end
        end
        "#{royal ? 'Royal' : 'Straight'} Flush of #{best_sf.first}"
      else
        nil
      end
    end

    def straight?(cards)
      cards.reject{|c| c.joker?}.reverse.each do |lowest|
        highest_card = lowest.rank
        s_ok = true
        jokers = cards.select{|c| c.joker?}.size
        used_cards = [lowest]
        (1..4).each do |step|
          needed_rank = Card::RANK_ORDER[lowest.value+step]
          if needed_rank
            # needed rank exists
            matching_card = cards.select{|c| c.rank == needed_rank}[0]
            if matching_card
              # have one
              highest_card = needed_rank
              used_cards << matching_card
            elsif jokers > 0
              # use joker
              jokers -= 1
              highest_card = needed_rank
              used_cards << cards.select{|c| c.joker?}.sort_by{|c| c.suit}[jokers]
            else
              # don't have one
              s_ok = false
            end
          else
            # needed rank ain't a thing
            s_ok = false
          end
        end
        if s_ok
          return "#{highest_card} high straight"
        end
      end
      if cards.any?{|c| c.rank == 'Ace' || c.joker?}
        s_ok = true
        jokers = cards.select{|c| c.joker?}.size
        ['Ace',2,3,4,5].each do |r|
          if cards.select{|c| c.rank == r}[0]
          elsif jokers > 0
            jokers -= 1
          else
            s_ok = false
          end
        end
        if s_ok
          return "5 high straight"
        end
      end

      nil
    end

    def full_house?(cards)
      true_three_ranks = cards.reject{|c| c.joker?}.group_by{|c| c.rank}.select do |r, cs|
        cs.size >= 3
      end
      true_pair_ranks = cards.reject{|c| c.joker?}.group_by{|c| c.rank}.select do |r, cs|
        cs.size >= 2
      end

      case cards.select{|c| c.joker?}.size
      when 0
        true_three_ranks.keys.sort_by{|k| Card::RANK_ORDER.index(k)}.reverse.each do |tr|
          a_pair = true_pair_ranks.keys.sort_by{|k| Card::RANK_ORDER.index(k)}.reject{ |r| r == tr  }[-1]
          if a_pair
            return "Full house, #{tr}s over #{a_pair}s"
          end
        end
        nil
      when 1
        # Have two pair, use Joker to make three. Other cases (two jokers & pair, joker & 3-of-a-kind)
        # would already be triggered by the check for 4-of-a-kind
        if true_pair_ranks.size >= 2
          used_pairs = true_pair_ranks.sort_by{|r, cs| Card::RANK_ORDER.index(r)}.reverse[0..1]
          return "Full house, #{used_pairs[0][0]}s over #{used_pairs[1][0]}s"
        end
        nil
      end
    end

    def flush?(cards)
      fsuits = cards.reject{|c| c.joker?}.group_by{|c| c.suit}.select do |s, cs| 
        (cs.size + cards.select{|c| c.joker?}.size) >= 5 
      end
      if fsuits.empty?
        nil
      else
        "Flush of #{fsuits.sort_by{|s, cs| Card::SUITS.index(cs.first.suit)}.last[0]}"
      end
    end

    def four?(cards)
      four_ranks = cards.reject{|c| c.joker?}.group_by{|c| c.rank}.select do |r, cs| 
        (cs.size + cards.select{|c| c.joker?}.size) >= 4
      end
      if four_ranks.empty?
        nil
      else
        best_four = four_ranks.sort_by{|r, cs| Card::RANK_ORDER.index(r)}.reverse.first
        "Four #{best_four[0]}s"
      end
    end

    def three?(cards)
      three_ranks = cards.reject{|c| c.joker?}.group_by{|c| c.rank}.select do |r, cs| 
        (cs.size + cards.select{|c| c.joker?}.size) >= 3
      end
      if three_ranks.empty?
        nil
      else
        best_three = three_ranks.sort_by{|r, cs| Card::RANK_ORDER.index(r)}.reverse.first
        "Three #{best_three[0]}s"
      end
    end

    def pair?(cards)
      pair_ranks = cards.reject{|c| c.joker?}.group_by{|c| c.rank}.select do |r, cs|
        (cs.size + cards.select{|c| c.joker?}.size) >= 2
      end
      if pair_ranks.empty?
        nil
      else
        best_pair = pair_ranks.sort_by{|r, cs| Card::RANK_ORDER.index(r)}.reverse.first
        "Pair of #{best_pair[0]}s"
      end
    end

    def two_pair?(cards)
      true_pair_ranks = cards.reject{|c| c.joker?}.group_by{|c| c.rank}.select do |r, cs|
        cs.size >= 2
      end
      high_card = cards.reject{|c| c.joker? || true_pair_ranks.keys.index(c.rank)}.sort_by{|c| Card::RANK_ORDER.index(c.rank)}.last
      joker_count = cards.select{|c| c.joker?}.size
      pair_ranks = true_pair_ranks.dup
      if joker_count > 0
        pair_ranks[high_card.rank] = [high_card, cards.select{|c| c.joker?}.first]
      end
      if pair_ranks.size < 2
        nil
      else
        best_pairs = pair_ranks.sort_by{|r, cs| Card::RANK_ORDER.index(r)}.reverse[0..1]
        "Two pair, #{best_pairs.first[0]}s and #{best_pairs[1][0]}s"
      end
    end

  end
end