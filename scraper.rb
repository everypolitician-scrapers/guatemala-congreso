#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class Members < Scraped::HTML
  def member_urls
    noko.css('a.dipu-name/@href').map(&:text)
  end

  def next_page
    noko.xpath('//a[contains(text(),"Siguiente")]/@href').text
  end
end

class Member < Scraped::HTML
  field :id do
    Addressable::URI.parse(url).query_values['id']
  end

  field :name do
    bio.css('h2').text.tidy
  end

  field :party do
    party_info.split(' - ').first
  end

  field :party_id do
    party_info.split(' - ').last
  end

  field :district do
    bio.xpath('.//p[contains(.,"Distrito al que representa")]//following-sibling::p[1]').text.tidy
  end

  field :birth_date do
    bio.xpath('.//p[contains(.,"Fecha de nacimiento")]//following-sibling::p[1]').text.tidy.split('-').reverse.join('-')
  end

  field :email do
    noko.css('.emai-diputado').text
  end

  field :photo do
    bio.css('img.img-responsive/@src').text
  end

  private

  def bio
    noko.css('#datos-generales')
  end

  def party_info
    bio.xpath('.//p[contains(.,"Partido al que representa")]//a').text.tidy
  end
end

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

url = 'https://www.congreso.gob.gt/el-congreso/organos-del-congreso/diputados-buscador-general/?tipo=Legislatura&legislatura=8'
members_pages = []
while !url.empty?
  page = scraper(url => Members)
  members_pages += page.member_urls
  url = page.next_page
end

data = members_pages.map { |url| scraper(url => Member).to_h }
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']
ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id], data)
