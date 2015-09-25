require 'spec_helper'

describe FactoryMom::Selfcare::ActiveRecordBaseChecker do
  # subject(FactoryMom::Selfcare::ActiveRecordBaseChecker)
  it 'captures AR errors' do
    subject.with_error_capturing do
      expect{ Post.new.save }.not_to raise_error
      expect(subject.active_record_errors.size).to eq 1

      expect{ Post.create }.not_to raise_error
      expect(subject.active_record_errors.size).to eq 2

      expect{ Post.new.save! }.to raise_error ActiveRecord::StatementInvalid # SQLite3::ConstraintException
      expect(subject.active_record_errors.size).to eq 3

      expect(puts subject.active_record_errors).to be_nil
    end
  end

  it 'properly executes as static' do
    expect(FactoryMom::Selfcare::ActiveRecordBaseChecker.with_error_capturing { Post.create }.active_record_errors.to_a.last.last.last.class).to eq ActiveRecord::StatementInvalid
  end
end
