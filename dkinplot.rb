require 'csv'
require 'json'
require 'time'
require "gnuplot"
require "optparse"

options = {
  verbose: false,
  output: nil,
  csv: nil,
  start: nil,
  stop: nil,
  resolution: "480x320",
  main_font: "terminus,12",
  legend_font: "terminus,8"
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: dkinplot.rb.rb [options]"

  opts.on("-v", "--verbose", "Enable noisy output") do
    options[:verbose] = true
  end

  opts.on("-o OUTPUT", "--output OUTPUT", "Write to OUTPUT") do |out|
    options[:output] = out
  end

  opts.on("-l CSV", "--csv FILE", "Plot logs from FILE") do |csv|
    options[:csv] = csv
  end

  opts.on("-s START", "--start START", String, "Begin plot at START") do |s|
    options[:start] = s
  end

  opts.on("-t STOP", "--stop STOP", String, "End plot at STOP") do |t|
    options[:stop] = t
  end

  opts.on("-r RESOLUTION", "--resolution RESOLUTION", String, "Output plot in RESOLUTION") do |r|
    options[:resolution] = r
  end

  opts.on("-mf FONT", "--main-font FONT", String, "Write plot with FONT") do |mf|
    options[:main_font] = mf
  end

  opts.on("-lf FONT", "--legend-font FONT", String, "Write plot's legend with FONT") do |lf|
    options[:legend_font] = lf
  end

  opts.on("-h", "--help", "Show help") do
    puts opts
    exit
  end
end

parser.parse!

if options[:csv] == nil || options[:output] == nil
  puts opts
  exit 1
end

#input = ARGV[0]
#
#if ARGV.length != 5
#  exit 1
#end

logs = CSV.read(options[:csv], headers: true)
return 1 if logs == nil

#min_timestamp = Time.parse(ARGV[1])
min_timestamp = Time.parse(options[:start])
return 1 if min_timestamp == nil
#max_timestamp = Time.parse(ARGV[2])
max_timestamp = Time.parse(options[:stop])
return 1 if max_timestamp == nil

#width, height = ARGV[4].split("x").map(&:to_i)
width, height = options[:resolution].split("x").map(&:to_i)
#samples = ARGV[3]
samples = (width > 66 ?  width.to_i - 66 : 0)
return 1 if width <= 0 || height <= 0 || samples <= 0

#sub_l = 3

dat = []
dat_i = 0
last_med = nil
logs.sort_by { |dose| dose['med'] }.each do |dose|
  timestamp = Time.parse(dose['timestamp'])
  if timestamp >= min_timestamp && timestamp <= max_timestamp
    if dose['med'] != last_med || last_med == nil
#      if sub_l == 0
#        break
#      end
#      sub_l -= 1
      if last_med != nil
        dat_i += 1
      end
      dat << {
        "Substance" => dose['med'], "Ingestions" => [],
        "ActivityX" => (0..samples-1).map { |i| (min_timestamp + ((max_timestamp - min_timestamp) / samples) * i).strftime("%Y-%m-%dT%H:%M:%S") },
        "ActivityY" => [],
        "BioavailOral" => 0.75,
        "BioavailIV" => 1.0
      }
      last_med = dose['med']
    end
    dat[dat_i]["Ingestions"] << { "Timestamp" => timestamp, "Amount" => dose['amount'].match(/(\d+)/)[0].to_f, "Route" => dose['route'] }
  end
end

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|
    plot.set "term pngcairo enhanced color size #{width},#{height} font \"#{options[:main_font]}\""
    plot.set "output \"#{options[:output]}\""
    plot.margin "10, 1, 3, 1"
    #plot.unset "ytics"
    plot.style "data lines"
    plot.set 'object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb"#101418" behind'
    plot.set 'style fill transparent solid 0.65'
    plot.set 'style data filledcurves above'
    plot.grid 'front lw 1 dashtype 2 lc rgb "white"'
    plot.key "spacing 1 width 0.5 maxrows 15 maxcols 5 samplen 1 font \"#{options[:legend_font]}\" inside nobox"
    #plot.key "box spacing 1.5 width 1 opaque"

    plot.xdata :time
    plot.timefmt '"%Y-%m-%dT%H:%M:%S"'
    plot.format ((max_timestamp - min_timestamp) > (3.5 * 24 * 60 * 60)) ? "x '%d.%m'" : "x '%H:%M'"
    plot.xtics (((max_timestamp - min_timestamp) > (8 * 30 * 24 * 60 * 60)) ? "#{60 * 60 * 24 * 30}" : (((max_timestamp - min_timestamp) > (30 * 24 * 60 * 60)) ? "#{60 * 60 * 24 * 14}" : ((max_timestamp - min_timestamp) > (3.5 * 24 * 60 * 60)) ? "#{60 * 60 * 24}" : "#{60 * 60 * 3}" ))
    plot.xtics "time nomirror scale 1"
    plot.format "y '%.1f'"
    plot.xrange "['#{options[:start]}':'#{options[:stop]}']"
    plot.yrange "[0.0:*]"
    plot.set "autoscale ymax"
    plot.samples "#{samples}"
    plot.set 'border lw 2 lc rgb "white"'
    plot.set 'xtics textcolor rgb "white"'
    plot.set 'ytics textcolor rgb "white"'
    plot.set 'xlabel "X" textcolor rgb "white"'
    plot.set 'ylabel "Y" textcolor rgb "white"'
    plot.set 'key textcolor rgb "white"'
    plot.style 'line 1 linecolor "white"'
    
    plot.title  ""
    plot.unset "xlabel"
    plot.ylabel "Plasma Concentration (mg/L)"
   
    #plot.data << Gnuplot::DataSet.new( [dat[0]["ActivityX"], dat[0]["ActivityY"]] ) { |ds|
    #  ds.using = "1:2"
    #  ds.with = ""
    #  ds.linewidth = "2"
    #  ds.title = dat[0]["Substance"]
    #}
    
    gp_dat = []
    for sub in dat
      for ts in sub['ActivityX']
        conc = 0.0
        for ing in sub['Ingestions']
          bioavail = ((ing['Route'] != nil && ing['Route'] == "intravenous") ? 1.0 : 0.5)
          vd = 5.0
          ka = (0.009 * 60)
          k = ((ing['Route'] != nil && ing['Route'] == "intravenous") ? (49.0 / vd) : 0.07)
          cl = ((ing['Route'] != nil && ing['Route'] == "intravenous") ? 20.0 : k * vd)
          kdif = (k - ka)
          dosetime = ((Time.parse(ts) - ing["Timestamp"]) / 60 / 60)
          dosetime = (dosetime < 0.0 ? 0.0 : dosetime)
          conc += (bioavail * ing['Amount'] * ka / (vd * kdif)) * (
            (Math.exp(-ka * dosetime) - Math.exp(-k * dosetime))
          )
        end
        sub["ActivityY"] << sprintf("%.3f", conc)
      end
    
      plot.data << Gnuplot::DataSet.new( [ sub['ActivityX'], sub['ActivityY'] ] ) { |ds|
        ds.using = "1:2"
        ds.with = "filledcurves above"
        ds.title = (sub['Substance'].length >= 26) ? ds.title = sub['Substance'].slice(0,23) + "..." : sub['Substance']
      }
    end
  end
end

puts "plotting: #{options[:csv]}"

puts JSON.pretty_generate(dat) if options[:verbose]

exit 0

