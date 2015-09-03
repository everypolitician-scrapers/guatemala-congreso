#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def date_from(text)
  return if text.to_s.empty?
  Date.parse(text).to_s rescue binding.pry
end

def parse_cfemail(str)
  list = str.scan(/../).map { |str| str.to_i(16) }
  key = list.shift
  list.map { |i| (key ^ i).chr }.join
end

def scrape_mp(url)
  noko = noko_for(url)
  content = noko.css('div#contenido')
  contact = noko.css('div#votos')

  data = { 
    image: content.css('article img/@src').first.text,
    area: content.xpath('.//b[contains(.,"Distrito al que representa")]/following-sibling::text()').text.tidy,
    birth_date: date_from(content.xpath('.//b[contains(.,"Nacimiento")]/following-sibling::text()').text.tidy),
    phone: contact.xpath('.//b[contains(.,"Teléfono")]/following-sibling::text()').text.tidy,
    email: parse_cfemail(noko.css('a.__cf_email__/@data-cfemail').text),
    source: url,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  data
end


def scrape_list(url)
  noko = noko_for(url)
  noko.css('table.dir_tabla tr').drop(1).each do |tr|
    tds = tr.css('td')
    mp_url = tds[1].css('a/@href').text
    data = { 
      id: mp_url[/id=(\d+)/, 1],
      name: tds[1].text.tidy,
      party: tds[2].text.tidy,
      faction: tds[3].text.tidy,
      term: 7,
    }.merge scrape_mp(mp_url)
    ScraperWiki.save_sqlite([:id, :term], data)
  end
end

term = { 
  id: 7,
  name: 'VII Legislatura de Guatemala',
  start_date: '2012-01-07',
  end_date: '2016-01-14',
  source: 'https://es.wikipedia.org/wiki/VII_Legislatura_de_Guatemala',
}
ScraperWiki.save_sqlite([:id], term, 'terms')

scrape_list('http://www.congreso.gob.gt/legislaturas.php')
