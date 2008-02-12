class LabResult < ActiveRecord::Base
  acts_as_reportable
  belongs_to :specimen_source, :class_name => 'Code'
  belongs_to :tested_at_uphl_yn, :class_name => 'Code'

  belongs_to :event

  validates_date :collection_date, :allow_nil => true
  validates_date :lab_test_date, :allow_nil => true

  def validate
    if !collection_date.blank? && !lab_test_date.blank?
      errors.add(:lab_test_date, "cannot precede collection date") if Chronic.parse(lab_test_date) < Chronic.parse(collection_date)
    end
  end
end
