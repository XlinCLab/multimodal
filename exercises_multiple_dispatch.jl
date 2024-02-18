#exercise 1
abstract type AbstractPerson end

struct Person <:AbstractPerson
    name::String
end

struct Student <:Person
    name::String
    grade::String
end

struct Leader <:Person
    name::String
    group::String
end

person_info(p::Person) = p.name
person_info(p::Student) = "Name " * p.name *", Grade "* p.grade
person_info(p::Leader) = "Name " * p.name *", Group "* p.group

s=Student("Petya","5")
person_info(s)
l=Leader("Olya", "Year 1")
person_info(l)

