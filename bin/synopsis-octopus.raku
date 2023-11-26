use Data::Dump::Tree;

use lib '../lib';

use PDF::Extract;
use Bill::Energy;

constant $file = '../private/bill.pdf';

#### Get PDF lines
my @lines = Extract.new(:$file).text.lines;

#### Parse PDF
class ChargeDates is Couplets {
    has $.regex = /'Flexible Octopus (' (<date>) ' - ' (<date>) ')'/;
    has $.dates = True;
}

class MeterIDs is Singlets {
    has $.regex = /'Energy Charges for Meter ' (.*)/;
}

class FuelTypes is Singlets {
    has $.regex = /'Total ' (<fueltype>) ' Charges'/;
}

class EnergyUses is Couplets {
    has $.regex = /(<decimal>) ' kWh @ ' (<decimal>) 'p/kWh'/;
}

class MeterReadings is Couplets {
    has $.regex = /(<decimal>) <ws> (<readtype>) <ws> reading/;
    has $.reverse = True;
}

class StandingCharges is Couplets {
    has $.regex = /(<integer>) ' days @ ' (<decimal>) 'p/day'/;
}


##### Make Invoice
my $b = Invoice.new(
    info => (
        charge-dates => ChargeDates.new(:@lines).list,
        meter-ids    => MeterIDs.new(:@lines).list,
        fueltypes    => FuelTypes.new(:@lines).list,
        readings     => MeterReadings.new(:@lines).list,
        energy-uses  => EnergyUses.new(:@lines).list,
        standings    => StandingCharges.new(:@lines).list,
    )
);

say $b.consumption;
say $b.total-charges;







