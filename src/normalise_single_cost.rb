# encoding: utf-8
class NormaliseSingleCost
  
  attr_accessor :original
  attr_accessor :value
  attr_accessor :cu, :cp, :cy, :vt1, :vt2, :vb1, :vb2, :pp, :pu, :ps, :ou, :per
  attr_accessor :parsed
  attr_accessor :parse_result
  attr_accessor :average_over_peak
  attr_accessor :energy_only
  
  CURRENCY_UNIT = {'£' => 100, '$' => 61, '€' => 87, 'p' => 1}
  CURRENCY_YEAR = {"1990" => 1.72663858,"1991" => 1.621875862,"1992" => 1.56311059,"1993" => 1.519410469,"1994" => 1.495752064,"1995" => 1.456727898,"1996" => 1.405856799,"1997" => 1.367727111,"1998" => 1.338061149,"1999" => 1.310547285,"2000" => 1.29520257,"2001" => 1.268246902,"2002" => 1.230148479,"2003" => 1.193474084,"2004" => 1.164144354,"2005" => 1.140966399,"2006" => 1.107174491,"2007" => 1.075002956,"2008" => 1.044026602,"2009" => 1.029155989,"2010" => 1.0}
  PREFIX = {'trn' => 1e12, 'tr' => 1e12, 'bn' => 1e9, 'p' => 1e15, 't' => 1e12,  'g' => 1e9, 'm' => 1e6, 'k' => 1e3}
  POWER_UNIT = { 'therm' => (41.868e9/396.83),'toe' => 41.868e9, 'boe' => 5.86152e9, 'wh' => (1*60*60), 'w' => (1*60*60*24*365.25), 'j' => 1.0, 'tcoal' => (26.1e9), 'bbl' => 5.86152e9 }
  OTHER_UNITS = {'unit' => 1.0, 'household' => 1.0, 'car' => 1.0, 'train' => 1.0, 'aeroplane' => 1.0}
  POWER_SUFFIX = {'peak' => :peak, 'average' => :average, 'p' => :peak, 'av' => :average, 'a' => :average}
  PERIOD_SUFFIX = {'/year' => 1.0, '/yr' => 1.0,'/y' => 1.0}
  
  P = " *(#{PREFIX.keys.join("|").gsub('|t|','|t(?!oe|herm)|')})?"
  CU = " *(#{CURRENCY_UNIT.keys.join("|").gsub('$','\$')})?"
  CY = " *\\((#{CURRENCY_YEAR.keys.join("|")})\\)?"
  PU = " *(#{POWER_UNIT.keys.join("|")})?"
  PS = " *(#{POWER_SUFFIX.keys.join("|")})?"
  OU = " *(#{OTHER_UNITS.keys.join("|")})?"
  V = " *(([0-9e.]+)( *- *([0-9e.]+))?)?"
  PER = ' */'
  
  def initialize(original, average_over_peak = nil)
    #puts 
    #puts original
    self.original = original
    self.average_over_peak = average_over_peak || 1.0
    self.parsed = false
  end
  
  def clean
    return unless self.original
    self.original.strip!
    self.original.gsub!(',','')
    self.original.gsub!('Â','')
  end

  def parse
    return parse_result if self.parsed
    clean
    if original.blank?
      self.parsed = true
      return self.parse_result = false
    elsif original =~ Regexp.new('^'+CU+P+CY+V+PER+V+P+PU+PS+OU+'$',Regexp::IGNORECASE)
      # puts "Match #{Regexp.new('^'+CU+P+CY+V+PER+V+P+PU+PS+OU+'$',Regexp::IGNORECASE).inspect}"
      @cu, @cp, @cy, ignore, @vt1, ignore, @vt2, ignore, @vb1, ignore, @vb2, @pp, @pu, @ps, @ou = *$~.captures
    elsif original =~ Regexp.new('^'+CU+CY+V+P+PER+V+P+PU+PS+OU+'$',Regexp::IGNORECASE)
      #puts "Match #{Regexp.new('^'+CU+CY+V+CP+P+V+PP+PU,Regexp::IGNORECASE).inspect}"
      @cu, @cy, ignore, @vt1, ignore, @vt2, @cp, ignore, @vb1, ignore, @vb2, @pp, @pu, @ps, @ou = *$~.captures
    elsif original =~ Regexp.new('^'+V+CU+P+CY+PER+V+P+PU+PS+OU+'$',Regexp::IGNORECASE)
      #puts "Match #{Regexp.new('^'+V+CU+CP+CY+P+V+PP+PU,Regexp::IGNORECASE).inspect}"
      ignore, @vt1, ignore, @vt2, @cu, @cp, @cy, ignore, @vb1, ignore, @vb2, @pp, @pu, @ps, @ou = *$~.captures
    elsif original =~ Regexp.new('^'+V+CU+CY+P+PER+V+P+PU+PS+OU+'$',Regexp::IGNORECASE)
      #puts "Match #{Regexp.new('^'+V+CU+CY+CP+P+V+PP+PU,Regexp::IGNORECASE).inspect}"      
      ignore, @vt1, ignore, @vt2, @cu, @cy, @cp, ignore, @vb1, ignore, @vb2, @pp, @pu, @ps, @ou = *$~.captures
    elsif original =~ Regexp.new('^'+V+P+PU+PS+OU+'$',Regexp::IGNORECASE)
      ignore, @vt1, ignore, @vt2, @pp, @pu, @ps, @ou = *$~.captures
      self.energy_only = true
    else
#     puts "#{original.inspect} not matched"
      self.parsed = true
      return self.parse_result = false
    end
#    puts "#{original.inspect} matched"
    self.parsed = true
    return self.parse_result = true
  end
  
  def normalise
    return "?" unless parse
    set_value unless self.value
    #p $~.captures
    #p %w{cu cp cy vt1 vt2 vb1 vb2 pp pu ps ou}.map {|x| "#{x}:#{self.send(x) || "nil"}"}.join(" ")
    adjust_for PREFIX, cp
    adjust_for CURRENCY_UNIT, cu
    adjust_for CURRENCY_YEAR, cy
    if energy_only
      adjust_for PREFIX, pp
      adjust_for POWER_UNIT, pu    
    else
      adjust_for_denominator PREFIX, pp
      adjust_for_denominator POWER_UNIT, pu
    end
    sort_values
    self.value
  end
  
  def sort_values
    self.value = self.value.sort
  end
  
  def set_value
    @vt1 = "1" if (@vt1 == nil || @vt1 == "")
    @vb1 = "1" if (@vb1 == nil || @vb1 == "")  

    self.value = 
    if vt2 && vb2
      [BigDecimal(vt1) / BigDecimal(vb2), BigDecimal(vt2) / BigDecimal(vb1)]
    elsif vt2
      [BigDecimal(vt1) / BigDecimal(vb1), BigDecimal(vt2) / BigDecimal(vb1)]
    elsif vb2
      [BigDecimal(vt1) / BigDecimal(vb1), BigDecimal(vt1) / BigDecimal(vb2)]
    else
      [BigDecimal(vt1) / BigDecimal(vb1)]
    end
  end
  
  def average_power
    return "?" unless parse
    set_value unless self.value
    self.ps ||= peak_average_unless_specified
    return "?" unless ps
    return self if POWER_SUFFIX[ps.to_s.downcase] == :average
    return "?" unless self.average_over_peak
    new_value = self.dup
    new_value.ps == "average"
    if energy_only
      new_value.value = self.value.map {|v| v * self.average_over_peak }
    else
      new_value.value = self.value.map {|v| v / self.average_over_peak }
    end
    new_value
  end
  
  def peak_power
    return "?" unless parse
    set_value unless self.value
    self.ps ||= peak_average_unless_specified
    return "?" unless ps
    return self if POWER_SUFFIX[ps.to_s.downcase] == :peak
    return "?" unless self.average_over_peak
    new_value = self.dup
    new_value.ps == "peak"
    if energy_only
      new_value.value = self.value.map {|v| v / self.average_over_peak }
    else
      new_value.value = self.value.map {|v| v * self.average_over_peak }
    end
    new_value    
  end
  
  def peak?
    return "?" unless parse
    (POWER_SUFFIX[ps.to_s.downcase]  || peak_average_unless_specified) == :peak
  end
  
  def average?
    return "?" unless parse
    (POWER_SUFFIX[ps.to_s.downcase] || peak_average_unless_specified) == :average    
  end
  
  def peak_average_unless_specified
    return "?" unless parse
    return :average unless pu
    pu.downcase == "w" ? :peak : :average
  end
  
  def coerce_peak_average(other)
    #p "Trying to coerce #{other.ps} into #{self.ps} (#{other.peak_average_unless_specified},#{self.peak_average_unless_specified}). I am peak? #{peak?.inspect} or average? #{average?.inspect}"
    #p ["before coerce", other.to_s,self.to_s]
    return other.peak_power if peak?
    return other.average_power if average?
    return other
  end
    
  def convert_to(unit)
    return "?" if self.normalise == "?"
    other_unit = NormaliseCost.new("1 #{unit}")
    #p [:ou,self.ou,other_unit.ou]
    #return "?" unless self.ou == other_unit.ou
    conversion_factor = other_unit.normalise
    return "?" if conversion_factor == "?"
    new_self = other_unit.coerce_peak_average(self)
    #p ["after coerce", new_self.to_s,other_unit.to_s]
    return "?" if new_self == "?"
    new_self.value.map { |c| c / conversion_factor.first }
  end
  
  def to_unit(_cu = nil, _cp = nil, _cy = nil , _pp = nil, _pu = nil, _ps = nil, _ou = nil)
    return nil unless parse
    if _cu || _cp || _cy || cu || cp || cy
      [_cu || cu,_cp || cp,'(',_cy || cy,')','/',_pp || pp,_pu || pu, _ps || ps, _ou || ou].join('')
    else
      [_pp || pp,_pu || pu, _ps || ps, _ou || ou].join('')
    end
  end
  
  def adjust_for(mapping,lookup)
    return if lookup.blank?
    lookup = lookup.downcase if lookup.respond_to?(:downcase)
    conversion_factor = BigDecimal(mapping[lookup].to_s)
    self.value = self.value.map do |v|
      #puts "#{lookup.inspect} in #{mapping.inspect} does #{v} * #{conversion_factor} = #{v * conversion_factor}"
      v * conversion_factor
    end
  end

  def adjust_for_denominator(mapping,lookup)
    return if lookup.blank?
    lookup = lookup.downcase if lookup.respond_to?(:downcase)
    conversion_factor = BigDecimal(mapping[lookup].to_s)
    self.value = self.value.map do |v|
      #puts "#{lookup.inspect} in #{mapping.inspect} does #{v} / #{conversion_factor} = #{v / conversion_factor}"
      v / conversion_factor
    end
  end

  def to_s
    return self.original unless parse
    top = (vt2 && vt2 != "") ? "#{vt1}-#{vt2}" : vt1
    bottom = (vb2 && vt2 != "") ? "#{vb1}-#{vb2}" : vb1
    top = "" if top == "1" && bottom != "1"
    bottom = "" if bottom == "1"
    [cu,cp,"(",cy,")",top,energy_only ? nil : "/",bottom,pp,pu,ps || peak_average_unless_specified ,ou].compact.join
  end
end