unit module Bill::Energy:ver<0.0.1>:auth<Steve Roe (librasteve@furnival.net)>;

# Some standard classes for Energy Bills

enum ReadingTypes = <Estimate Actual>;
enum FuelTypes = <Electricity Gas>;

class Tariff is export {
    has $.fuel-type;
    has $.fuel-units;

    has $.currency = 'GBP';
    has $.date-start;
    has $.date-end;
    has $.standing-period = 1;    #days
    has $.standing-charge;
    has $.unit-charge;
}

class Meter is export {
    has $.id;
    has $.fuel-type;
    has $.fuel-units;
}

class Reading is export {
    has $.meter;
    has $.date;
    has $.value;
    
    method units-used {
       $!meter-last - $!meter-first 
    }

    method total-days {
       $!date-last - $!date-first 
    }
}

class Rating {


}

class Charge is export {
    has $.tariff;
    has $.fuel-type;

    has $.date-start;
    has $.date-end;

    has $.sc-prorata;

    method amount {

    }
}

class Bill::Energy is export {
    has $.id;

    has $.date-bill;
    has $.period-start;
    has $.period-end;

    has $.name;
    has $.address;
    has @.charges;

    method total-amount {
        sum @!charges>>.amount
    }
}


#`[[
class Address {
    has $.street;
    has $.city;
    has $.post-code;
}

class Tariff {
    has $.name;
    has $.rate;

    method new($name, $rate) {
        self.bless(:$name, :$rate);
    }
}

class MeterReading {
    has $.date;
    has $.value;

    method new($date, $value) {
        self.bless(:$date, :$value);
    }
}

class EnergyBill {
    has Address $.address;
    has Tariff $.electricity-tariff;
    has Tariff $.gas-tariff;
    has @.electricity-meter-readings;
    has @.gas-meter-readings;

    method add-electricity-reading($date, $value) {
        my $reading = MeterReading.new(:$date, :$value);
        @!electricity-meter-readings.push($reading);
    }

    method add-gas-reading($date, $value) {
        my $reading = MeterReading.new(:$date, :$value);
        @!gas-meter-readings.push($reading);
    }

    method calculate-electricity-cost() {
        my $total-cost = 0;
        for @!electricity-meter-readings -> $reading {
            $total-cost += $reading.value * $.electricity-tariff.rate;
        }
        return $total-cost;
    }

    method calculate-gas-cost() {
        my $total-cost = 0;
        for @!gas-meter-readings -> $reading {
            $total-cost += $reading.value * $.gas-tariff.rate;
        }
        return $total-cost;
    }

    method generate-monthly-report() {
        my $electricity-cost = self.calculate-electricity-cost();
        my $gas-cost = self.calculate-gas-cost();

        say "Monthly Energy Bill";
        say "Address: $.address.street, $.address.city, $.address.postal-code";
        say "Electricity Cost: \${$electricity-cost.fmt('%.2f')}";
        say "Gas Cost: \${$gas-cost.fmt('%.2f')}";
        say "Total Cost: \${($electricity-cost + $gas-cost).fmt('%.2f')}";
    }
}

# Example Usage:
my $address = Address.new(street => "123 Main St", city => "Cityville", postal-code => "12345");
my $electricity-tariff = Tariff.new(name => "Standard Electricity", rate => 0.15);
my $gas-tariff = Tariff.new(name => "Standard Gas", rate => 0.05);

my $energy-bill = EnergyBill.new(address => $address, electricity-tariff => $electricity-tariff, gas-tariff => $gas-tariff);

$energy-bill.add-electricity-reading('2023-10-01', 1000);
$energy-bill.add-gas-reading('2023-10-01', 50);

$energy-bill.generate-monthly-report();
#]]
