class SectionHighlight < ApplicationModel
  belongs_to :section
  belongs_to :entry
  
  validates_presence_of :section, :entry, :publication_date
  validates_uniqueness_of :entry_id, :scope => [:section_id, :publication_date]
  
  acts_as_list :scope => 'section_id = #{section_id} AND publication_date = \'#{publication_date.to_s(:db)}\''
  
  def new_position=(new_pos)
    insert_at(new_pos)
  end
end