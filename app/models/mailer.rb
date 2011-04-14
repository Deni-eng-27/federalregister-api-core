class Mailer < ActionMailer::Base
  include SendGrid
  helper :entry, :text
  
  sendgrid_enable :opentracking, :clicktracking
  
  def password_reset_instructions(user)
    sendgrid_category "Admin Password Reset"
    
    subject    "FR2 Admin Password Reset"
    from       "FR2 Admin <info@criticaljuncture.org>"
    recipients user.email
    sent_on    Time.current
    body       :user => user, :edit_password_reset_url => edit_admin_password_reset_url(user.perishable_token)
  end
  
  def subscription_confirmation(subscription)
    sendgrid_category "Subscription Confirmation"
    
    subject    "[FR] #{subscription.mailing_list.title}"
    from       "Federal Register Subscriptions <subscriptions@mail.federalregister.gov>"
    recipients subscription.email
    sent_on    Time.current
    body       :subscription => subscription
  end

  def unsubscribe_notice(subscription)
    sendgrid_category "Subscription Unsubscribe"
    
    subject "[FR] #{subscription.mailing_list.title}"
    from       "Federal Register Subscriptions <subscriptions@mail.federalregister.gov>"
    recipients subscription.email
    sent_on    Time.current
    body       :subscription => subscription
  end
  
  def mailing_list(mailing_list, results, subscriptions)
    sendgrid_category "Subscription"
    sendgrid_recipients subscriptions.map(&:email)
    sendgrid_substitute "(((token)))", subscriptions.map(&:token)
    
    toc = TableOfContentsPresenter.new(results)
    agencies = toc.agencies
    if mailing_list.search.agency_ids.present?
      agencies = agencies.select{|a|  mailing_list.search.agency_ids.include?(a.agency.id.to_s)}
    end
    entries_without_agencies = toc.entries_without_agencies
    
    subject "[FR] #{mailing_list.title}"
    from       "Federal Register Subscriptions <subscriptions@mail.federalregister.gov>"
    recipients 'nobody@federalregister.gov' # should use sendgrid_recipients for actual recipient list
    sent_on    Time.current
    body       :mailing_list => mailing_list, :results => results, :agencies => agencies, :entries_without_agencies => entries_without_agencies
  end
  
  def entry_email(entry_email)
    sendgrid_category "Email a Friend"
    sendgrid_recipients entry_email.all_recipient_emails
    
    subject "[FR] #{entry_email.entry.title}"
    from entry_email.sender
    recipients 'nobody@mail.federalregister.gov' # should use sendgrid_recipients for actual recipient list
    sent_on Time.current
    body :entry => entry_email.entry, :sender => entry_email.sender, :message => entry_email.message
  end
end
