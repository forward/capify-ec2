#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'fog'

class CapifyCloudwatch
  # Threshold => color
  # Color is applied if metric exceeds the threshold, KEEP IN ORDER
  Colors = {
    0 => :green,
    50 => :yellow,
    90 => :red
  }

  def initialize(key_id, secret)
    @ticks = %w[▁ ▂ ▃ ▄ ▅ ▆ ▇]
    @cw = Fog::AWS::CloudWatch.new(:aws_access_key_id => key_id,
                                   :aws_secret_access_key => secret)
  end

  def get_metric(instance_id, metric, hours = 1)
    range = hours * (60 * 60)
    time = Time.new
    start = DateTime.parse((time - range).to_s)
    finish = DateTime.parse(time.to_s)

    dimensions = [{
      "Name" => "InstanceId",
      "Value" => instance_id
    }]

    result = @cw.get_metric_statistics({'Namespace' => 'AWS/EC2',
                                        'MetricName' => metric,
                                        'Period' => 120,
                                        'Statistics' => ['Average'],
                                        'StartTime' => start,
                                        'EndTime' => finish,
                                        'Dimensions' => dimensions})

    dp = result.body.fetch("GetMetricStatisticsResult", {})["Datapoints"]

    if dp
      return get_spark_line(dp.map {|x| x["Average"]})
    end
    return ""
  end

  def colorize_output(output, value)
    colored = output
    Colors.each do |threshold, color|
      if value >= threshold
        colored = output.send(color)
      end
    end
    colored
  end

  def get_spark_line(values)
    scale = @ticks.length - 1

    if values
      final = values.last.round
      bar = values.map { |x| @ticks[(x / 100.0 * scale).floor] }.join
      return colorize_output(bar.ljust(10) + " #{final}%", final)
    else
      ""
    end
  end
end
