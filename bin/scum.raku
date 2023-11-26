use Data::Dump::Tree;

use PDF::Extract;
use DateTime::Parse;   #zef install librasteve fork / change to DateTime::Grammar

constant $file = '../private/bill.pdf';

##### Regexen
my regex integer  { \d* }
my regex decimal  { \d* \. \d* }

my @fueltype = <Gas Electricity>;
my @readtype = <Estimated Customer>;

my subset FuelType of Str where * ~~ @fueltype.any;
my subset ReadType of Str where * ~~ @readtype.any;

sub make-date( $d ) {
    given DateTime::Parse.new($d.trim, rule=> 'date') {
        Date.new( |$_ )
    }
}
my regex date {
    <-[-)]>+                           #grab chars
    <?{ make-date( ~$/ ) ~~ Date }>    #assert coerces to Date
}


##### Anchors
class Anchors {
    has @.lines;
    has $.regex;
    has $.type;
    has $.reverse;
    has $.dates;
    has @!index;
    has @!contents;
    has $!loaded = False;

    method loadme {
        return if $!loaded;

        @!lines = Extract.new(:$file).text.lines;

        my $i=0;
        for @!lines -> $line {
            if $line ~~ $.regex {
                @!index.push($i);

                given $.type {
                    when 'singlets' {
                        @!contents.push( ~$0 )
                    }
                    when 'couplets' {
                        @!contents.push( ~$0 => ~$1 );
                    }
                }
            }
            $i++
        }

        @!contents.=map(*.antipair) if $.reverse;
        @!contents.=map({$_.key.&make-date => $_.value.&make-date}) if $.dates;

        $!loaded = True;
    }

    method index  { $.loadme; @!index    }
    method list   { $.loadme; @!contents }
    method hash   { (@.index Z=> @.list).Hash }
}

class Singlets is Anchors {
    has $.type = 'singlets';
}

class Couplets is Anchors {
    has $.type = 'couplets';
}

class ChargeDates is Couplets {
    has $.regex = /'Flexible Octopus (' (<date>) ' - ' (<date>) ')'/;
    has $.dates = True;
}

class MeterIDs is Singlets {
    has $.regex = /'Energy Charges for Meter ' (.*)/;
}

class FuelTypes is Singlets {
    has $.regex = /'Total ' (@fueltype) ' Charges'/;
}

class EnergyUses is Couplets {
    has $.regex = /(<decimal>) ' kWh @ ' (<decimal>) 'p/kWh'/;
}

class MeterReadings is Couplets {
    has $.regex = /(<decimal>) <ws> (@readtype) <ws> reading/;
    has $.reverse = True;
}

class StandingCharges is Couplets {
    has $.regex = /(<integer>) ' days @ ' (<decimal>) 'p/day'/;
}

#### Load Couplets
my %pdf-info = (
    charge-dates => ChargeDates.new.list,
    meter-ids    => MeterIDs.new.list,
    fueltypes    => FuelTypes.new.list,
    readings     => MeterReadings.new.list,
    energy-uses  => EnergyUses.new.list,
    standings    => StandingCharges.new.list,
);

##### Bill

class Tariff {
    has Str      $.name = '';   #stub for now
    has FuelType $.fueltype    is rw;
    has Rat()    $.energy-rate is rw; #p/kWh
    has Rat()    $.scday-rate  is rw; #p/day

    method check {
        ($!fueltype & $!energy-rate & $!scday-rate).so
    }
}

class Charge {
    has          %.pdf-info;
    has Tariff   $.tariff handles<fueltype energy-rate scday-rate>;
    has Date     @.dates;
    has Str      $.meter-id;
    has ReadType @.readtype;
    has Rat()    @.readings;
    has Rat()    $.energy-used;
    has Int()    $.day-count;
    has Rat      $.vat = <5/100>;
    
    method TWEAK {
        my %p := %!pdf-info;
        $!tariff = Tariff.new;

        @!dates    = %p<charge-dates>.shift.kv;
        $!meter-id = %p<meter-ids>.shift;
        $.fueltype = %p<fueltypes>.shift;
        for ^2 {
            given %p<readings>.shift {
                @!readtype.push: .key;
                @!readings.push: .value;
            }
        }
        ($!energy-used, $.energy-rate) = %p<energy-uses>.shift.kv;
        ($!day-count,   $.scday-rate ) = %p<standings>.shift.kv;
    }

    method check {
        (@!dates[1] - @!dates[0]) == ($!day-count -  1)  &&    #dates are inclusive
        (@!dates    & @!readtype    & @!readings) == 2   &&
        ($!meter-id & $!energy-used & $!day-count).so    &&
        $!tariff.check
    }

    method consumption {
        @!readings[1] - @!readings[0]
    }

    method total-charges {
        ( ( $!energy-used * $.energy-rate ) + ($!day-count * $.scday-rate ) )
        / 100
        * (1 + $!vat)
    }
}

class Bill {
    has         %.pdf-info;
#    has Address $.address;     #stub for now
    has Charge  @.charges;

    submethod TWEAK {
        @!charges = Charge.new(:%!pdf-info) xx +%!pdf-info<charge-dates>;

        warn 'bad extract' unless @!charges>>.check.all.so;
    }

    method consumption {
        @!charges>>.consumption.sum.fmt( 'Total Consumption = %.2f kWh' )
    }

    method total-charges {
        @!charges>>.total-charges.sum.fmt('Total Charges (incl.VAT) = %.2f');
    }
}

my $b = Bill.new(:%pdf-info);

say $b.consumption;
say $b.total-charges;







