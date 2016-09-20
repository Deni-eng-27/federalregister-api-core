class EntryApiRepresentation < ApiRepresentation
  self.default_index_fields_json = [:title, :type, :abstract, :document_number, :html_url, :pdf_url, :public_inspection_pdf_url, :publication_date, :agencies, :excerpts]
  self.default_index_fields_csv = [:title, :type, :agency_names, :abstract, :document_number, :html_url, :pdf_url, :publication_date]
  self.default_index_fields_rss = [:title, :abstract, :document_number, :publication_date, :agencies, :topics]

  def self.default_show_fields_json
    all_fields - [:excerpts, :agency_names, :docket_id, :president]
  end

  def self.default_show_fields_csv
    all_fields - [:excerpts, :agency_names, :docket_id, :president]
  end

  field(:abstract)
  field(:action)
  field(:agencies, :select => :id, :include => {:agency_name_assignments => {:agency_name => :agency}}) do |entry|
    entry.agency_name_assignments.map(&:agency_name).compact.map do |agency_name|
      agency = agency_name.agency
      if agency
        {
          :raw_name => agency_name.name,
          :name     => agency.name,
          :id       => agency.id,
          :url      => agency_url(agency),
          :json_url => api_v1_agency_url(agency.id, :format => :json),
          :parent_id => agency.parent_id,
          :slug      => agency.slug
        }
      else
        {
          :raw_name => agency_name.name
        }
      end
    end
  end
  field(:agency_names, :include => {:agency_names => :agency}) {|e| e.agency_names.compact.map{|a| a.agency.try(:name) || a.name}}
  field(:body_html_url, :select => [:document_file_path, :publication_date, :document_number]) {|e| entry_full_text_url(e)}
  field(:cfr_references, :include => :entry_cfr_references, select: [:publication_date]) do |entry|
    entry.entry_cfr_references.map do |cfr_reference|
      citation_url = if cfr_reference.chapter.present? && cfr_reference.part.present?
        select_cfr_citation_url(entry.publication_date, cfr_reference.title, cfr_reference.part, nil)
      else
        nil
      end

      {
        :title => cfr_reference.title,
        :part => cfr_reference.part,
        :chapter => cfr_reference.chapter,
        :citation_url => citation_url
      }
    end
  end
  field(:citation)
  field(:comments_close_on, :include => :comments_close_date){|e| e.comments_close_on}
  field(:comment_url, :select => [:comment_url, :comment_url_override]){|e| e.calculated_comment_url}
  field(:corrections, :include => :corrections){|e| e.corrections.map{|c| api_v1_entry_url(c.document_number, :format => :json)}}
  field(:correction_of, :include => :correction_of, :select => :correction_of_id){|e| api_v1_entry_url(e.correction_of.document_number, :format => :json) if e.correction_of}
  field(:dates)
  field(:docket_id, :include => :docket_numbers){|e| e.docket_numbers.first.try(:number)} # backwards compatible for now
  field(:docket_ids, :include => :docket_numbers){|e| e.docket_numbers.map(&:number)}
  field(:document_number)
  field(:effective_on, :include => :effective_date)
  field(:end_page)
  field(:excerpts, :select => [:document_number, :publication_date, :document_file_path, :abstract]) {|e| (e.excerpts.raw_text || e.excerpts.abstract) if e.respond_to?(:excerpts) && e.excerpts}
  field(:executive_order_notes)
  field(:executive_order_number)
  field(:full_text_xml_url, :select => [:publication_date, :document_file_path, :full_xml_updated_at]){|e| entry_xml_url(e) if e.should_have_full_xml?}
  field(:html_url, :select => [:publication_date, :document_number, :title]){|e| entry_url(e)}
  field(:images, :include => [:extracted_graphics, :gpo_graphic_usages]) do |entry|
    graphics = entry.extracted_graphics
    gpo_graphics = entry.processed_gpo_graphics

    if graphics.present?
      graphics.inject({}) do |hsh, graphic|
        hsh[graphic.identifier] = graphic.graphic.styles.inject({}) do |hsh, style|
          hsh[style[0]] = style[1].attachment.send(:url, style[0])
          hsh
        end
        hsh
      end
    elsif gpo_graphics.present?
      gpo_graphics.inject({}) do |hsh, gpo_graphic|
        next unless gpo_graphic.xml_identifier

        hsh[gpo_graphic.xml_identifier] = gpo_graphic.graphic.styles.inject({}) do |hsh, style|
          hsh[style[0]] = style[1].attachment.send(:url, style[0])
          hsh
        end
        hsh
      end
    else
      {}
    end
  end
  field(:json_url, :select => :document_number) {|e| api_v1_entry_url(e.document_number, :format => :json)}
  field(:mods_url, :select => [:publication_date, :document_number]){|e| e.source_url(:mods)}
  field(:page_length, :select => [:start_page, :end_page]) {|e| e.human_length }
  field(:pdf_url, :select => [:publication_date, :document_number]){|e| e.source_url('pdf')}
  field(:public_inspection_pdf_url, :select => :document_number, :include => :public_inspection_document) {|e| e.public_inspection_document.try(:pdf).try(:url)}
  field(:president, :select => [:granule_class, :signing_date, :publication_date]) do |entry|
    president = entry.president
    if president
      {:name => president.full_name, :identifier => president.identifier}
    end
  end
  field(:publication_date)
  field(:raw_text_url, :select => [:publication_date, :document_file_path]){|e| entry_raw_text_url(e)}
  field(:regulation_id_number_info, :include => {:entry_regulation_id_numbers => :current_regulatory_plan}) do |entry|
    values = entry.entry_regulation_id_numbers.map do |e_rin|
      regulatory_plan = e_rin.current_regulatory_plan
      if regulatory_plan
        regulatory_plan_info = {
          :xml_url => regulatory_plan.source_url(:xml),
          :issue => regulatory_plan.issue,
          :title => regulatory_plan.title,
          :priority_category => regulatory_plan.priority_category,
          :html_url => regulatory_plan_url(regulatory_plan)
        }
      end
      [e_rin.regulation_id_number, regulatory_plan_info]
    end

    Hash[*values.flatten]
  end

  field(:regulations_dot_gov_info, :include => :docket, :select => [:regulations_dot_gov_docket_id, :comment_url, :comment_url_override]) do |entry|
    vals = {}

    if entry.regulations_dot_gov_document_id
      vals.merge!(:document_id => entry.regulations_dot_gov_document_id)
    end

    if entry.regulations_dot_gov_agency_id
      vals.merge!(:agency_id => entry.regulations_dot_gov_agency_id)
    end


    docket = entry.docket
    if docket
      docket_info = {
        :docket_id => docket.id,
        :regulation_id_number => docket.regulation_id_number,
        :title => docket.title,
        :comments_count => docket.comments_count,
        :comments_url => regulations_dot_gov_docket_comments_url(docket.id),
        :supporting_documents_count => docket.docket_documents_count,
        :supporting_documents => docket.docket_documents.sort_by(&:id).reverse[0..9].map do |doc|
          {
            :title => doc.title,
            :document_id => doc.id
          }
        end,
        :metadata => docket.metadata
      }

      if docket.regulation_id_number.present?
        regulatory_plan = RegulatoryPlan.current.find_by_regulation_id_number(docket.regulation_id_number)
        if regulatory_plan
          docket_info.deep_merge!(
            :regulatory_plan => {
              html_url: regulatory_plan_url(regulatory_plan),
              title: regulatory_plan.title
            }
          )
        end
      end
    end

    if docket_info
      vals.deep_merge!(docket_info)
    end

    vals
  end

  field(:regulation_id_numbers, :include => :entry_regulation_id_numbers) {|e| e.entry_regulation_id_numbers.map{|r| r.regulation_id_number}}
  field(:regulations_dot_gov_url, :select => [:comment_url, :comment_url_override]) {|e| e.regulations_dot_gov_url}
  field(:start_page)
  field(:significant)
  field(:signing_date)
  field(:subtype, :select => :presidential_document_type_id){|e| e.presidential_document_type.try(:name)}
  field(:title)
  field(:toc_subject)
  field(:toc_doc)
  field(:topics, :include => {:topic_assignments => :topic}) {|e| e.topic_assignments.map{|x| x.topic.try(:name)}.compact}
  field(:type, :select => :granule_class){|e| e.entry_type}
  field(:volume)
end
