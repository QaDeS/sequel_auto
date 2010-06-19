# TODO extract into helper
require 'sequel'
URL = 'oracle://test:test@localhost/XE'
#URL = 'postgres://test:test@localhost:5433/postgres'
#URL = 'sqlite://test.db'
#URL = 'mysql://test:test@localhost/test'
DB = Sequel.connect URL

Sequel::Model.plugin :auto
DB.default_schema!
%w[nodes logins users contents metadatas departments_employees employees
departments foos_bars bars foos].each { |t| puts "dropping #{t}"; begin DB.drop_table t rescue puts $!; end }

describe Sequel::Plugins::Auto do
  it "should create self references" do
    DB.create_table :nodes do
      primary_key :id
      String :name
      foreign_key :parent_id, :nodes
    end

    class Node < Sequel::Model; auto_assoc; end
    Node.create(:name => 'Root').add_child(Node.new(:name => 'Child 1'))

    root = Node.first
    root.name.should == 'Root'
    child = root.children.first
    child.name.should == 'Child 1'
    child.parent.should == root
  end

  it "should create one_to_many references" do
    DB.create_table :users do
      primary_key :id
      String :name
    end
    DB.create_table :logins do
      primary_key :id
      String :username
      foreign_key :user_id, :users
    end

    class User < Sequel::Model; auto_assoc; end
    class Login < Sequel::Model; auto_assoc; end
    User.create(:name => 'Me').add_login(Login.new(:username => 'uname1'))

    user = User.first
    user.name.should == 'Me'
    login = user.logins.first
    login.username.should == 'uname1'
    login.user.should == user
  end

  it "should create one_to_one references" do
    DB.create_table :metadatas do
      primary_key :id
      String :filename
    end
    DB.create_table :contents do
      primary_key :id
      String :txt
      foreign_key :metadata_id, :metadatas
    end
    DB.add_index :contents, :metadata_id, :unique => true

    class Metadata < Sequel::Model; auto_assoc; end
    class Content < Sequel::Model; auto_assoc; end
    Metadata.create(:filename => 'file1').content = Content.new(:txt => 'foobar')

    meta = Metadata.first
    meta.filename.should == 'file1'
    content = meta.content
    content.txt.should == 'foobar'
    content.metadatum.should == meta
  end

  it "should create many_to_many references" do
    DB.create_table :departments do
      primary_key :id
      String :name
    end
    DB.create_table :employees do
      primary_key :id
      String :name
    end
    DB.create_table :departments_employees do
      primary_key :id
      foreign_key :department_id, :departments
      foreign_key :employee_id, :employees
    end
    DB.add_index :departments_employees, [:department_id, :employee_id], :unique => true, :name => :dep_emp_ixd

    class Department < Sequel::Model; auto_assoc; end
    class Employee < Sequel::Model; auto_assoc; end
    Department.create(:name => 'Development').add_employee Employee.new(:name => 'Me')

    dep = Department.first
    dep.name.should == 'Development'
    employee = Employee.first
    employee.name.should == 'Me'
    employee.departments.first.should == dep
    dep.employees.first.should == employee
  end

  it "should automatically create models" do
    DB.create_table :foos do
      primary_key :id
      String :name
    end
    DB.create_table :bars do
      primary_key :id
      String :name
    end
    DB.create_table :foos_bars do
      primary_key :id
      foreign_key :foo_id, :foos
      foreign_key :bar_id, :bars
    end

    classes = Sequel::Model.auto_models
    
    classes.should include(Foo, Bar)
    Foo.create(:name => 'MyFoo').add_bar Bar.create(:name => 'MyBar')
    foo = Foo.first
    foo.name.should == 'MyFoo'
    bar = foo.bars.first
    bar.name.should == 'MyBar'
  end
end

