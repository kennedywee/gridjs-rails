# frozen_string_literal: true

require_relative "gridjs_rails/version"

module GridjsRails
  class Error < StandardError; end

  class Builder
    def initialize(model, columns, associations = {})
      @model = model
      @columns = columns
      @associations = associations
    end

    def build(params)
      limit = params[:limit] || 10
      offset = params[:offset] || 0
      search_query = params[:search]
    
      records = @model.all
    
      if search_query.present?
        search_conditions = []
        search_values = []
    
        @columns.each do |column|
          if @associations.key?(column)
            assoc_key = column
            assoc_value = @associations[assoc_key]
            assoc_table = assoc_key.to_s.pluralize
            search_conditions << "#{assoc_table}.#{assoc_value} LIKE ?"
          else
            search_conditions << "#{column} LIKE ?"
          end
          search_values << "%#{search_query}%"
        end
    
        records = records.joins(@associations.keys).where(search_conditions.join(" OR "), *search_values)
      end
    
      records = apply_associations(records, params)
    
      total_count = records.count
      records = records.limit(limit).offset(offset)
    
      data = process_records(records)
    
      { total: total_count, data: data }
    end

    private
      def apply_associations(records, params)
        sort_column = params[:order]
        sort_direction = params[:dir]
      
        @associations.each do |assoc, assoc_column|
          records = records.includes(assoc)
        end
      
        if sort_column && sort_direction
          if @associations.key?(sort_column.to_sym)
            assoc_value = @associations[sort_column.to_sym]
            assoc_table = sort_column.to_s.pluralize
            records = records.joins(sort_column.to_sym).order("#{assoc_table}.#{assoc_value} #{sort_direction}")
          else
            records = records.order("#{sort_column} #{sort_direction}")
          end
        end
      
        records
      end
    
    

      def process_records(records)
        records.map do |record|
          row = {}
          @columns.each do |column|
            if @associations.key?(column)
              assoc_key = column
              assoc_value = @associations[assoc_key]
              assoc_record = record.send(assoc_key)
              assoc_column_value = assoc_record.send(assoc_value)
              row[column] = assoc_column_value
            else
              row[column] = record.send(column)
            end
          end
          row
        end
      end

  end
end

