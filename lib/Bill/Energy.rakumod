unit module Bill::Energy:ver<0.0.1>:auth<Steve Roe (librasteve@furnival.net)>;

# Some standard classes for Energy Bills

use Data::Dump::Tree;   #debug

use DateTime::Parse;   #zef install librasteve fork / change to DateTime::Grammar

##### Regexen & Types
my @fueltype = <Gas Electricity>;
my @readtype = <Estimated Customer>;

my $fj = @fueltype.any;     #\   make Junctions for subset check
my $rj = @fueltype.any;     #/    (workaround)

my subset FuelType of Str where * ~~ $fj;
my subset ReadType of Str where * ~~ $rj;

my regex integer  is export { \d* }
my regex decimal  is export { \d* \. \d* }
my regex fueltype is export { @fueltype }
my regex readtype is export { @readtype }

sub make-date( $d ) {
    given DateTime::Parse.new($d.trim, rule=> 'date') {
        Date.new( |$_ )
    }
}
my regex date is export {
    <-[-)]>+                           #grab chars
    <?{ make-date( ~$/ ) ~~ Date }>    #assert coerces to Date
}


##### Anchors & N-lets
class Singlets { ... }
class Doublets { ... }

class Anchors {
    has @!lines is built;
    has $.regex;
    has $.reverse;
    has $.dates;

    method list {
        my @contents = gather {
            for @!lines {
                when $.regex {
                    given self {
                        when Singlets {
                            take ~$0
                        }
                        when Doublets {
                            take ~$0 => ~$1
                        }
                    }
                }
            }
        }

        @contents.=map(*.antipair) if $.reverse;
        @contents.=map({$_.key.&make-date => $_.value.&make-date}) if $.dates;

        @contents
    }
}
class Singlets is Anchors is export {}
class Doublets is Anchors is export {}

class TextBlock is export {
    has @!lines is built;
    has $.range;

    method list {
        @!lines[|$.range].grep(*.so)
    }
}


##### Bill

#| TODO - make singleton
class Tariff {
    has FuelType $.fueltype is rw;
    has Rat()    $.kwh-rate is rw; #p/kWh
    has Rat()    $.day-rate is rw; #p/day

    method check {
        ($!fueltype & $!kwh-rate & $!day-rate).so
    }
}

class Charge {
    has          %.info;
    has Tariff   $.tariff handles<fueltype kwh-rate day-rate>;
    has Date     @.dates;
    has Str      $.meter-id;
    has ReadType @.readtype;
    has Rat()    @.readings;
    has Rat()    $.kwh-used;
    has Int()    $.day-count;
    has Rat      $.vat = <5/100>;

    method TWEAK {
        my %i := %!info;

        my ($fueltype, $kwh-rate, $day-rate);

        @!dates    = %i<charge-dates>.shift.kv;
        $!meter-id = %i<meter-ids>.shift;
        $fueltype  = %i<fueltypes>.shift;
        for ^2 {
            given %i<readings>.shift {
                @!readtype.push: .key;
                @!readings.push: .value;
            }
        }
        ($!kwh-used,  $kwh-rate) = %i<energy-uses>.shift.kv;
        ($!day-count, $day-rate) = %i<standings>.shift.kv;

        $!tariff = Tariff.new(:$fueltype, :$kwh-rate, :$day-rate);
    }

    method check {
        (@!dates[1] - @!dates[0]) == ($!day-count -  1)  &&    #dates are inclusive
                (@!dates    & @!readtype    & @!readings) == 2   &&
                ($!meter-id & $!kwh-used & $!day-count).so    &&
                $!tariff.check
    }

    method consumption {
        @!readings[1] - @!readings[0]
    }

    method total-charges {
        ( ($!kwh-used * $.kwh-rate ) + ($!day-count * $.day-rate ) )
                / 100
                * (1 + $!vat)
    }
}

class Invoice is export {
    has         %.info;
    has  $.contact;
    has Charge  @.charges;

    submethod TWEAK {
        @!charges = Charge.new(:%!info) xx +%!info<charge-dates>;
        warn 'bad extract' unless @!charges>>.check.all.so;

        $!contact = %!info<contact>;
    }

    method consumption {
        @!charges>>.consumption.sum.fmt( 'Total Consumption = %.2f kWh' )
    }

    method total-charges {
        @!charges>>.total-charges.sum.fmt('Total Charges (incl.VAT) = %.2f');
    }
}


