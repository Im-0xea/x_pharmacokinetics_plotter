require 'csv'
require 'json'
require 'time'
require "gnuplot"

if ARGV.length != 5
  exit 1
end

rows = CSV.read(ARGV[0], headers: true)
min_timestamp = Time.parse(ARGV[1])
max_timestamp = Time.parse(ARGV[2])
samples = ARGV[3]
width, height = ARGV[4].split("x").map(&:to_i)

#sub_l = 3

dat = []
dat_i = 0
last_med = nil
rows.sort_by { |row| row['med'] }.each do |row|
  timestamp = Time.parse(row['timestamp'])
  if timestamp >= min_timestamp && timestamp <= max_timestamp
    if row['med'] != last_med || last_med == nil
#      if sub_l == 0
#        break
#      end
#      sub_l -= 1
      if last_med != nil
        dat_i += 1
      end
      dat << {
        "Substance" => row['med'], "Ingestions" => [],
        "ActivityX" => (0..Integer(samples)-1).map { |i| (min_timestamp + ((max_timestamp - min_timestamp) / Integer(samples)) * i).strftime("%Y-%m-%dT%H:%M:%S") },
        "ActivityY" => [],
        "BioavailOral" => 0.75,
        "BioavailIV" => 1.0
      }
      last_med = row['med']
    end
    dat[dat_i]["Ingestions"] << { "Timestamp" => timestamp, "Amount" => row['amount'].match(/(\d+)/)[0].to_f, "Route" => row['route'] }
  end
end

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|
    plot.set "term pngcairo enhanced color size #{width},#{height} font 'terminus,12'"
    plot.set 'output "nlog_graph.png"'
    #plot.margin "0, 0, 2.75, 0"
    #plot.unset "ytics"
    plot.style "data lines"
    plot.set 'object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb"#101418" behind'
    plot.set 'style fill transparent solid 0.65'
    plot.set 'style data filledcurves above'
    plot.grid 'front lw 1 dashtype 2 lc rgb "white"'
    plot.key 'spacing 1 width 0.5 maxrows 15 maxcols 5 samplen 1 font "terminus,8" inside nobox'
    #plot.key "box spacing 1.5 width 1 opaque"

    plot.xdata :time
    plot.timefmt '"%Y-%m-%dT%H:%M:%S"'
    plot.format ((max_timestamp - min_timestamp) > (3.5 * 24 * 60 * 60)) ? "x '%d.%m'" : "x '%H:%M'"
    plot.xtics (((max_timestamp - min_timestamp) > (8 * 30 * 24 * 60 * 60)) ? "#{60 * 60 * 24 * 30}" : (((max_timestamp - min_timestamp) > (30 * 24 * 60 * 60)) ? "#{60 * 60 * 24 * 14}" : ((max_timestamp - min_timestamp) > (3.5 * 24 * 60 * 60)) ? "#{60 * 60 * 24}" : "#{60 * 60 * 3}" ))
    plot.xtics "time nomirror scale 1"
    plot.format "y '%.1f'"
    plot.xrange "['#{ARGV[1]}':'#{ARGV[2]}']"
    plot.yrange "[0.0:*]"
    plot.set "autoscale ymax"
    plot.samples ARGV[3]
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
puts JSON.pretty_generate(dat)
