class AgencyAssignment < ApplicationModel
  belongs_to :agency
  belongs_to :assignable, :polymorphic => true
  belongs_to :entry, :foreign_key => :assignable_id
  belongs_to :agency_name
  
  after_create :increment_entry_counter_cache
  after_destroy :decrement_entry_counter_cache
  
  acts_as_list :scope => 'assignable_id = #{assignable_id} AND assignable_type = \'#{assignable_type}\''
  
  def self.recalculate!
    connection.execute("UPDATE agency_names
                        LEFT JOIN agencies
                          ON agencies.id = agency_names.agency_id
                        SET agency_names.agency_id = NULL
                        WHERE agencies.id IS NULL AND agency_names.agency_id IS NOT NULL")
    connection.execute("TRUNCATE agency_assignments")
    connection.execute("INSERT INTO agency_assignments (id, assignable_id, assignable_type, position, agency_id)
      SELECT agency_name_assignments.id, agency_name_assignments.assignable_id, agency_name_assignments.assignable_type, agency_name_assignments.position, agency_names.agency_id
      FROM agency_name_assignments
      JOIN agency_names ON agency_names.id = agency_name_assignments.agency_name_id
      WHERE agency_names.agency_id IS NOT NULL")
    
    # not all agencies have entries, so wouldn't be matched by the query that does the real calculation
    connection.execute "UPDATE agencies SET entries_count = 0"
    connection.execute "UPDATE agencies,
                (
                 SELECT agency_id, COUNT(DISTINCT(assignable_id)) AS entries_count
                 FROM agency_assignments
                 WHERE agency_assignments.assignable_type = 'Entry'
                 GROUP BY agency_assignments.agency_id
                ) AS agency_assignment_counts
             SET agencies.entries_count = agency_assignment_counts.entries_count
             WHERE agencies.id = agency_assignment_counts.agency_id"
  end
  
  private
  
  def increment_entry_counter_cache
    Agency.increment_counter(:entries_count, agency_id) if assignable_type == 'Entry'
    true
  end
  
  def decrement_entry_counter_cache
    Agency.decrement_counter(:entries_count, agency_id) if assignable_type == 'Entry'
    true
  end
  
end
