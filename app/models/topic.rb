=begin Schema Information

 Table name: topics

  id         :integer(4)      not null, primary key
  name       :string(255)
  created_at :datetime
  updated_at :datetime
  group_name :string(255)

=end Schema Information

class Topic < ActiveRecord::Base
  has_many :topic_assignments
  has_many :entries, :through => :topic_assignments

  def to_param
    name
  end
  
  before_save :generate_group_name
  
  private
  
  def generate_group_name
    group_name = self.name.downcase
    group_name.gsub!(/[^a-z ]/,' ')
    group_name.gsub!(/\b(?:and|by|the|a|an|of|in|on|to|for|s|etc|promotion)\b/, ' ')

    group_name.gsub!(/ {2,}/, ' ')
    group_name.gsub!(/^ /, '')
    group_name.gsub!(/ $/, '')

    words = group_name.split(' ').map {|w| w.singularize}[0 .. 1]
    if words[0] == words[1]
      words.pop
    end
    
    self.group_name = words.join(' ')
  end
end

