# encoding: utf-8
require_relative '../src/normalise_cost'

describe NormaliseCost do 
  
  it "should put simple costs into p(2010)/J" do
    NormaliseCost.new("£(2010) 1/J").normalise.map(&:to_f).should == [100]
    NormaliseCost.new("£(2010) 1/kJ").normalise.map(&:to_f).should == [0.1]
    NormaliseCost.new("£k(2010) 1/kJ").normalise.map(&:to_f).should == [100]
    NormaliseCost.new("£m(2010) 1/MJ").normalise.map(&:to_f).should == [100]
    NormaliseCost.new("£bn(2010) 1/GJ").normalise.map(&:to_f).should == [100]
    NormaliseCost.new("£trn(2010) 1/TJ").normalise.map(&:to_f).should == [100]    
    NormaliseCost.new("£trn(2010) 1000/PJ").normalise.map(&:to_f).should == [100]
    NormaliseCost.new("£(2010) 1/PJ").normalise.map(&:to_f).should == [1e-13]        
    NormaliseCost.new("£(2009) 50/MWh").normalise.map(&:to_f).should == [1.4293833180555555e-06]
    NormaliseCost.new("£M(2009) 3/MW").normalise.map(&:to_f).should == [9.783595606129744e-06]
    NormaliseCost.new("5 £(2009)bn/MWh").normalise.map(&:to_f).should == [142.93833180555555]
    NormaliseCost.new("£m(2009)/6TWh").normalise.map(&:to_f).should == [4.764611060185185e-09] 
    NormaliseCost.new("$(2000)100/toe").normalise.map(&:to_f).should == [1.8870582967899112e-07] 
    NormaliseCost.new("£M(2010) 1/GWp").normalise.map(&:to_f).should == [3.168808781402895e-09]
  end
  
  it "should deal with numbers that contain commas" do
    NormaliseCost.new("£(2009) 50,000/MWh").normalise.map(&:to_f).should == [0.0014293833180555556]
  end
  
  it "should deal with nil values" do
    NormaliseCost.new(nil).normalise.should == "?"
  end
  
  it "should deal with blank values" do
    NormaliseCost.new("").normalise.should == "?"
    NormaliseCost.new(" ").normalise.should == "?"
  end
  
  it "should deal with random characters created by encoding errors" do
    NormaliseCost.new("Â£(2009) 50,000/MWh").normalise.map(&:to_f).should == [0.0014293833180555556]
  end
  
  it "should be able to convert to other values" do
    NormaliseCost.new("£(2009) 50/MWh").convert_to("£(2009)/MWh").map(&:to_f).should == [50]
    NormaliseCost.new("5 £(2009)bn/MWh").convert_to("£(2009)bn/MWh").map(&:to_f).should == [5]
  end
  
  it "should be able to cope when the other value in convert_to is unparsable" do
    NormaliseCost.new("£(2009) 50/MWh").convert_to("").map(&:to_f).should == [1.4293833180555555e-06]
    NormaliseCost.new("£(2009) 50/MWh").convert_to("?").should == "?"
    NormaliseCost.new("£(2009) 50/MWh").convert_to("asdfas").should == "?"
  end
  
  it "should deal with costs that have above and bellow the line components (i.e., £(2009) 8/2MWh)" do
    NormaliseCost.new("£(2009) 8/2MWh").convert_to("£(2009)/MWh").map(&:to_f).should == [4]
  end
  
  it "should deal with cost ranges, returning the results as a normalised array" do
    NormaliseCost.new("£M(2009) 3-10 /MW").normalise.map(&:to_f).should == [9.783595606129744e-06, 3.2611985353765815e-05]
    NormaliseCost.new("£M(2009) 3-10 /MW").convert_to("£(2009)M/MW").map(&:to_f).should == [3.0, 10.0] 
  end
  
  it "should cope with high low and low high ranges, always returning low high" do
    NormaliseCost.new("£M(2009) 10-3 /MW").normalise.map(&:to_f).should == [9.783595606129744e-06, 3.2611985353765815e-05]
  end
  
  it "should allow a new cost format to be created from this one" do
    NormaliseCost.new("£M(2009) 3-10 /MW").to_unit.should == "£M(2009)/MW"
    NormaliseCost.new("£M(2009) 3-10 /MW").to_unit(nil,nil,2010).should == "£M(2010)/MW"
    NormaliseCost.new("£M(2009) 3-10 /MW").to_unit('€',nil,2010).should == "€M(2010)/MW"
    NormaliseCost.new("1 TJ").to_unit().should == "TJ"
  end
  
  it "should allow a new cost to be created per physical unit" do
    NormaliseCost.new("£(2010) 10/unit").normalise.map(&:to_f).should == [1000] # 1000 pence
    NormaliseCost.new("£(2010) 1000/unit").convert_to("£k(2010)/unit").map(&:to_f).should == [1]
  end
  
  it "should allow power to be peak or average, but by default it has no effect" do
    bald = NormaliseCost.new("£M(2010) 1/GWp").normalise.map(&:to_f)
    NormaliseCost.new("£M(2010) 1/GWp").normalise.map(&:to_f).should == bald
    NormaliseCost.new("£M(2010) 1/GWpeak").normalise.map(&:to_f).should == bald
    NormaliseCost.new("£M(2010) 1/GWa").normalise.map(&:to_f).should == bald
    NormaliseCost.new("£M(2010) 1/GWaverage").normalise.map(&:to_f).should == bald  
  end
  
  it "should allow power to be peak or average, assuming W are peak and anything else is average by default. Should scale £ if appropriate % is given" do
    NormaliseCost.new("£M(2010) 1/GW").peak?.should == true
    NormaliseCost.new("£M(2010) 1/GW").average?.should == false

    NormaliseCost.new("£M(2010) 1/TWh").peak?.should == false
    NormaliseCost.new("£M(2010) 1/TWh").average?.should == true

    NormaliseCost.new("£M(2010) 1/GWp").peak?.should == true
    NormaliseCost.new("£M(2010) 1/GWp").average?.should == false

    NormaliseCost.new("£M(2010) 1/GWav").peak?.should == false
    NormaliseCost.new("£M(2010) 1/GWav").average?.should == true
           
    bald = NormaliseCost.new("£M(2010) 1/GW").normalise.map(&:to_f).first
    
    NormaliseCost.new("£M(2010) 1/GW").average_power.normalise.map(&:to_f).first.should be_within(1.0e-12).of(bald)
    NormaliseCost.new("£M(2010) 1/GW",0.5).average_power.normalise.map(&:to_f).first.should be_within(1.0e-12).of(bald*2.0)
    NormaliseCost.new("£M(2010) 1/GWp",0.5).average_power.normalise.map(&:to_f).first.should be_within(1.0e-12).of(bald*2.0)
    NormaliseCost.new("£M(2010) 1/GWpeak",0.5).average_power.normalise.map(&:to_f).first.should be_within(1.0e-12).of(bald*2.0)
    NormaliseCost.new("£M(2010) 1/GWa",0.5).average_power.normalise.map(&:to_f).first.should == bald
    NormaliseCost.new("£M(2010) 1/GWaverage",0.5).average_power.normalise.map(&:to_f).first.should == bald  

    NormaliseCost.new("£M(2010) 1/GW",0.5).peak_power.normalise.map(&:to_f).first.should == bald
    NormaliseCost.new("£M(2010) 1/GWp",0.5).peak_power.normalise.map(&:to_f).first.should == bald
    NormaliseCost.new("£M(2010) 1/GWpeak",0.5).peak_power.normalise.map(&:to_f).first.should == bald
    NormaliseCost.new("£M(2010) 1/GWa",0.5).peak_power.normalise.map(&:to_f).first.should be_within(1.0e-12).of(bald*0.5)
    NormaliseCost.new("£M(2010) 1/GWaverage",0.5).peak_power.normalise.map(&:to_f).first.should be_within(1.0e-12).of(bald*0.5)   
  end
  
  it "should allow conversion from and to peak and average powers, assuming W are peak and other things are average" do
    NormaliseCost.new("£M(2010) 1/GWp").convert_to("£M(2010)/GWp").map(&:to_f).should == [1.0]
    NormaliseCost.new("£M(2010) 1/GW").convert_to("£M(2010)/GWp").map(&:to_f).should == [1.0]
    NormaliseCost.new("£M(2010) 1/GW").convert_to("£M(2010)/GW").map(&:to_f).should == [1.0]
    NormaliseCost.new("£M(2010) 1/GW").convert_to("£M(2010)/GWaverage").should == [1.0]
    NormaliseCost.new("£M(2010) 1/GW",0.5).convert_to("£M(2010)/GWaverage").map(&:to_f).should == [2.0]
    NormaliseCost.new("£M(2010) 1/GWa",0.5).convert_to("£M(2010)/GWp").map(&:to_f).should == [0.5]    
    NormaliseCost.new("£M(2010) 1/GWa",0.5).convert_to("£M(2010)/GWa").map(&:to_f).should == [1.0]
  end
  
  it "should assume a conversion factor of one between peak and average, unless otherwise specified" do
    NormaliseCost.new("£bn(2010) 10/GW").convert_to("£(2010)bn/GWaverage").map(&:to_f).first.should be_within(0.1).of(10)
  end
  
  it "should be able to normalise powers without costs" do
    NormaliseCost.new("1 GW").normalise.map(&:to_f).should == [(1*60*60*24*365.25)*1e9]
    NormaliseCost.new("1 GW").convert_to("GW").map(&:to_f).should == [1]
    NormaliseCost.new("1 GW").convert_to("MW").map(&:to_f).should == [1000]
    NormaliseCost.new("1 GW").convert_to("TWh").map(&:to_f).should == [8.766]    
    NormaliseCost.new("1 GW",0.5).average_power.normalise.map(&:to_f).should == [(1*60*60*24*365.25)*1e9*0.5]
    NormaliseCost.new("1 GW",0.5).average_power.convert_to("GW").map(&:to_f).should == [0.5]
    NormaliseCost.new("1 GWpeak",0.5).convert_to("GWaverage").map(&:to_f).should == [0.5]    
  end
  
  it "should be able to convert basic sums such as £M(2010) 1/GWpeak plus £(2010)30/GJ" do
    NormaliseCost.new("£(2009) 25/blah plus £(2009) 25/blah").normalise.should == "?"
    NormaliseCost.new("£(2009) 25/MWh plus £(2009) 25/blah").normalise.should == "?"
    NormaliseCost.new("£(2009) 25/blah plus £(2009) 25/MWh").normalise.should == "?"
    NormaliseCost.new("£(2009) 25/MWh plus £(2009) 25/MWh").normalise.map(&:to_f).should == [1.4293833180555555e-06]
    NormaliseCost.new("£(2009) 0-25/MWh plus £(2009) 25/MWh").normalise.map(&:to_f).should == [7.146916590277777e-07, 1.4293833180555555e-06] 
    NormaliseCost.new("£(2009) 1000/kWpeak plus £(2009) 25/MWh",0.5).normalise.map(&:to_f).should == [ 3.975890194404359e-06]
    NormaliseCost.new("£(2009) 1000/kW plus £(2009) 25/MWh",0.5).normalise.map(&:to_f).should == [ 3.975890194404359e-06]
    NormaliseCost.new("£M(2009) 3-10 /MW plus £M(2009) 3-10 /kWh").to_unit('€',nil,2010).should == "€M(2010)/MW"
  end
end