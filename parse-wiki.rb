# -*- encoding : utf-8 -*-
require 'nokogiri'
require 'eat'
require 'pandoc-ruby'
require "unicode_utils/each_grapheme"

@articles_to_ignore = ['HIV']
memo = {}

def make_wiki_edit_uri name
	"http://en.wikipedia.org/w/index.php?title=#{name.gsub(" ", "_")}&action=edit"
end

def get_wiki_edit_content name
	@wikipedia_call ||= {}
	@wikipedia_call[name] ||= Nokogiri::XML(eat(make_wiki_edit_uri(name), :timeout => 10)).at_xpath('//textarea')

	@wikipedia_call[name]    
end

def get_all_main_articles name, articles, depth
	return if depth == 4

	wikipage = get_wiki_edit_content(name)
	return if wikipage.nil?

	articles << name
	puts "#{"\t" * (depth - 1)}#{name}"

	wikipage.content.scan(/\{\{Main\|.*|\}\}/).each do |main_match|
		next if main_match.nil?

		main_match.scan(/\|([\w\s\'\(\)]+)/).each do |article|
			next if article.first.start_with? "List of"
			next if article.first.start_with? "Timeline of"
			next if @articles_to_ignore.include? article.first
			next if articles.include? article.first.strip

			get_all_main_articles(article.first.strip, articles, depth + 1)
		end
	end
end

def convert_content_to_markdown name
	wikimarkup = get_wiki_edit_content(name).content
	wikimarkup.gsub! "&lt;", "<"
	wikimarkup.gsub! "<!--linked-->", ""
	wikimarkup.gsub! /\{\{Main\|[\w\s\'\(\)\|]+\}\}/, ""
	
	wikimarkup.gsub! /<ref>.*?<\/ref>/m, ""
	wikimarkup.gsub! /<ref[\w\s\=\"\-\–\.\&\:\'\,\_\?]+\/>/m, ""
	wikimarkup.gsub! /<ref[\w\s\=\"\-\–\.\&\:\'\,\_\?]+>.*?<\/ref>/m, ""
	wikimarkup.gsub! /<ref name=\".*?\">.*?<\/ref>/m, ""
	wikimarkup.gsub! /<ref name=\".*?\"\s?\/>/m, ""
					  
	wikimarkup.gsub! /\[\[File\:.*\]\]/, ""

	wikimarkup.gsub! /\{\{\\\}\}/im, ""
	wikimarkup.gsub! /\{\{nowrap.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{unbulleted.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{See also.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Pie.*?\}\}/mi, ""
	wikimarkup.gsub! /\{\{Largest.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Main.*?\}\}/mi, ""
	wikimarkup.gsub! /\{\{legend.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Weather.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{TOC.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Redirect.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Further.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Current.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Flag.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Reflist.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Wikivoyage.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{wiktionary.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Previously.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{see.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Coord.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{Pp.*?\}\}/im, ""
	wikimarkup.gsub! /\{\{IPA.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{lang\-.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{About.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Use.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Soviet.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Multiple.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{cleanup.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{POV.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{History.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Disambiguation.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Empty.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Expand.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Portal.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{Russia.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{\\\#tag.*?\}\}/i, ""
	wikimarkup.gsub! /\{\{clear\}\}/i, ""
	wikimarkup.gsub! /\{\{-\}\}/, ""

	wikimarkup.scan(/\{\{Convert\|([0-9\.\,]+)\|(km|mi|km2|mi2|sqmi)\|(km|mi|km2|mi2|sqmi)\}\}/i).each do |distance, from, to|
		wikimarkup.gsub!("{{Convert|#{distance}|#{from}|#{to}}}", "#{distance}#{from}")
	end
	wikimarkup.scan(/\{\{convert\|([0-9\.\,]+)\|(km|mi|km2|mi2|sqmi)\|(km|mi|km2|mi2|sqmi)\}\}/i).each do |distance, from, to|
		wikimarkup.gsub!("{{convert|#{distance}|#{from}|#{to}}}", "#{distance}#{from}")
	end
	wikimarkup.scan(/\{\{convert\|([0-9\.]+)\|km\|0\|abbr=on\}\}/i).each do |distance|
		wikimarkup.gsub!("{{convert|#{distance.first}|km|0|abbr=on}}", "#{distance}km")
	end
	wikimarkup.scan(/\{\{convert\|([0-9\.]+)\|m\|0\|abbr=on\}\}/i).each do |distance|
		wikimarkup.gsub!("{{convert|#{distance.first}|m|0|abbr=on}}", "#{distance}km")
	end
	wikimarkup.scan(/\{\{convert\|([0-9\.]+)\|km\|mi\|0\|abbr=on\}\}/i).each do |distance|
		wikimarkup.gsub!("{{convert|#{distance.first}|km|mi|0|abbr=on}}", "#{distance}km")
	end
	wikimarkup.scan(/\{\{convert\|([0-9\.]+)\|km\|mi\|1\|abbr=on\}\}/i).each do |distance|
		wikimarkup.gsub!("{{convert|#{distance.first}|km|mi|1|abbr=on}}", "#{distance}km")
	end

	wikimarkup.scan(/\{\{convert\|(.*)\|(.*)\|(.*)\|(.*)\|disp=or\}\}/i).each do |temp,u1,u2,u3|
		wikimarkup.gsub!("{{convert|#{temp}|#{u1}|#{u2}|#{u3}|disp=or}}", "#{temp}#{u1}")
	end

	wikimarkup.scan(/\{\{RailGauge\|([0-9]+)mm\}\}/i).each do |mm|
		wikimarkup.gsub!("{{RailGauge|#{mm.first}mm}}", "#{mm}mm")
	end

	wikimarkup.scan(/\[\"(.*?)\"\]/i).each do |number|
		wikimarkup.gsub!("[\"#{number.first}\"]", number.first)
	end

	wikimarkup.scan(/\[\[([\w\s ',\.\!\#\&\-\–\)\(]+)\]\]/).each do |link|
		wikimarkup.gsub!("[[#{link.first}]]", link.first)
	end
	wikimarkup.scan(/\[\[([\w\s ',\.\!\#\&\-\–\)\(]+)\|([\w\s ',\.\!\#\&\-\–\)\(]+)\]\]/).each do |link, label|
		wikimarkup.gsub!("[[#{link}|#{label}]]", label)
	end
	wikimarkup.scan(/\[\[(.*?)\]\]/).each do |link|
		wikimarkup.gsub!("[[#{link.first}]]", link.first)
	end

	wikimarkup = wikimarkup[0..wikimarkup.index("==See also==")-1] unless wikimarkup.index("==See also==").nil? 

	wikimarkup.gsub! /\{\{.*?\}\}/, ""
	wikimarkup.gsub! /\{\{Infobox.*?\}\}/im, ""

	@converter = PandocRuby.new(wikimarkup, :from => :mediawiki, :to => :markdown)
	wikimarkup = @converter.convert

	wikimarkup.gsub! "()", ""
	wikimarkup.gsub! "or ,", ""
	wikimarkup.gsub! " ,", ","

	wikimarkup
end

articles = []
get_all_main_articles ARGV[0], articles, 1

articles.each do |article|
	File.open("articles/#{article.gsub(" ", "-").gsub("'", "")}.md".downcase!, "w") do | file |
		puts "Writing #{article}"
		file.write convert_content_to_markdown(article)
	end
end