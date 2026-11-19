require "json"; require "bundler/setup"; require "ruby_llm"
rows = File.readlines(ARGV[0]).map { JSON.parse(_1) }
by = Hash.new { |h,k| h[k] = Hash.new(0) }
rows.each do |r|
  u = r["usage"] || {}
  m = r["model"]; b = by[m]
  b[:calls]+=1; b[:in]+=u["input_tokens"].to_i; b[:out]+=u["output_tokens"].to_i
  b[:cr]+=u["cache_read_tokens"].to_i; b[:cw]+=u["cache_write_tokens"].to_i; b[:err]+=1 if r["error"]
end
total=0
by.each do |m,b|
  info = (RubyLLM.models.find(m) rescue nil)
  pr = info&.pricing&.to_h&.dig(:text_tokens,:standard); pin = pr&.dig(:input_per_million); pout = pr&.dig(:output_per_million)
  cost = pr ? (b[:in]*pin + b[:out]*pout + b[:cw]*pr[:cache_write_input_per_million].to_f + b[:cr]*pr[:cache_read_input_per_million].to_f)/1e6 : nil
  total += cost.to_f
  puts "#{m}: calls=#{b[:calls]} in=#{b[:in]} out=#{b[:out]} cache_w=#{b[:cw]} cache_r=#{b[:cr]} errs=#{b[:err]} est_cost=#{cost ? format('$%.3f',cost) : 'n/a'} (prices in=#{pin} out=#{pout})"
end
puts format("TOTAL est: $%.3f", total)
