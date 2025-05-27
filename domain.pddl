(define (domain rapid)

    (:requirements :strips :typing :negative-preconditions :disjunctive-preconditions
        :equality :quantified-preconditions :conditional-effects
    )

    (:types
        entity location - object
        vehicle team resource - entity
        affected-location safe-location - location
        freight-vehicle transit-vehicle - vehicle
        medical-support-team rescue-team - team
    )

    (:predicates
        (at ?obj - entity ?loc - location)
        (in ?obj - team ?vehicle - vehicle)
        (needs-rescue ?loc - affected-location)
        (needs-evacuation ?loc - affected-location)
        (needs-medical-support ?loc - affected-location)
        (not-accessible ?loc1 ?loc2 - location ?obj - vehicle)
    )

    (:functions
        (total-cost)
        (time)
        (plan-length)
        (priority ?location - location) ; Higher the value, Higher the priority
        (distance ?location1 ?location2 - location)
        (per-unit-distance-cost ?vehicle - vehicle)
        (per-unit-distance-time ?vehicle - vehicle)
        (stock ?location - location ?res - resource)
        (needs-resource ?loc - affected-location ?res - resource)
        (capacity ?vehicle - vehicle)
        (evacuating ?veh - transit-vehicle ?from - affected-location)
        (contains ?vehicle - freight-vehicle ?resource - resource)
        (person-to-evacuate ?loc - affected-location)
        (per-unit-distribution-cost ?res - resource)
        (team-size ?team - team)
    )

    (:action PickUpTeam
        :parameters (?team - team ?loc - location ?vehicle - transit-vehicle)
        :precondition (and
            (at ?vehicle ?loc)
            (at ?team ?loc)
            (>= (capacity ?vehicle) (team-size ?team))
        )
        :effect (and
            (not (at ?team ?loc))
            (in ?team ?vehicle)
            (decrease (capacity ?vehicle) (team-size ?team))
            (increase (time) (team-size ?team))
            (increase (plan-length) 1)
        )
    )

    (:action DropOffTeam
        :parameters (?team - team ?loc - location ?vehicle - transit-vehicle)
        :precondition (and
            (at ?vehicle ?loc)
            (in ?team ?vehicle)
        )
        :effect (and
            (not (in ?team ?vehicle))
            (at ?team ?loc)
            (increase (time) (team-size ?team))
            (increase (plan-length) 1)
            (increase (capacity ?vehicle) (team-size ?team))
        )
    )

    (:action EmergencyRescue
        :parameters (?loc - affected-location ?rescuers - rescue-team)
        :precondition (and
            (needs-rescue ?loc)
            (at ?rescuers ?loc)
            (forall
                (?other_loc - affected-location)
                (or
                    (>= (priority ?loc) (priority ?other_loc))
                    (and
                        (< (priority ?loc) (priority ?other_loc))
                        (not (needs-rescue ?other_loc))
                        (not (needs-evacuation ?other_loc))
                        (not (needs-medical-support ?other_loc))
                    )
                )
            )
        )
        :effect (and
            (not (needs-rescue ?loc))
            (increase (time) 5)
            (increase (plan-length) 1)
        )
    )

    (:action ProvideMedicalSupport
        :parameters (?loc - affected-location ?team - medical-support-team)
        :precondition (and
            (needs-medical-support ?loc)
            (at ?team ?loc)
            (forall
                (?other_loc - affected-location)
                (or
                    (>= (priority ?loc) (priority ?other_loc))
                    (and
                        (< (priority ?loc) (priority ?other_loc))
                        (not (needs-rescue ?other_loc))
                        (not (needs-evacuation ?other_loc))
                        (not (needs-medical-support ?other_loc))
                    )
                )
            )
        )
        :effect (and
            (not (needs-medical-support ?loc))
            (increase (time) 5)
            (increase (plan-length) 1)
        )
    )

    (:action PickPeopleToEvacuate
        :parameters (?loc - affected-location ?vehicle - transit-vehicle)
        :precondition (and
            (needs-evacuation ?loc)
            (> (person-to-evacuate ?loc) 0)
            (at ?vehicle ?loc)
            (> (capacity ?vehicle) 0)
            (forall
                (?other_loc - affected-location)
                (or
                    (>= (priority ?loc) (priority ?other_loc))
                    (and
                        (< (priority ?loc) (priority ?other_loc))
                        (not (needs-rescue ?other_loc))
                        (not (needs-evacuation ?other_loc))
                        (not (needs-medical-support ?other_loc))
                    )
                )
            )
        )
        :effect (and
            (increase (plan-length) 1)
            (when
                (<= (person-to-evacuate ?loc) (capacity ?vehicle))
                (and
                    (decrease (capacity ?vehicle) (person-to-evacuate ?loc))
                    (increase (evacuating ?vehicle ?loc) (person-to-evacuate ?loc))
                    (assign (person-to-evacuate ?loc) 0)
                    (increase (time) (person-to-evacuate ?loc))
                )
            )
            (when
                (> (person-to-evacuate ?loc) (capacity ?vehicle))
                (and
                    (decrease (person-to-evacuate ?loc) (capacity ?vehicle))
                    (increase (evacuating ?vehicle ?loc) (capacity ?vehicle))
                    (assign (capacity ?vehicle) 0)
                    (increase (time) (capacity ?vehicle))
                )
            )
        )
    )

    (:action DropEvacuatedPeople
        :parameters (?to - safe-location ?vehicle - transit-vehicle ?from - affected-location)
        :precondition (and
            (at ?vehicle ?to)
            (> (evacuating ?vehicle ?from) 0)
        )
        :effect (and
            (increase (time) (evacuating ?vehicle ?from))
            (increase (plan-length) 1)
            (increase (capacity ?vehicle) (evacuating ?vehicle ?from))
            (assign (evacuating ?vehicle ?from) 0)
            (when
                (= (person-to-evacuate ?from) 0)
                (not (needs-evacuation ?from))
            )
        )
    )

    

    (:action MoveVehicle
        :parameters (?vehicle - vehicle ?from ?to - location)
        :precondition (and
            (at ?vehicle ?from)
            (not (not-accessible ?from ?to ?vehicle))
            (not (= ?from ?to))
        )
        :effect (and
            (not (at ?vehicle ?from))
            (at ?vehicle ?to)
            (increase (plan-length) 1)
            (increase (total-cost) (* (distance ?from ?to) (per-unit-distance-cost ?vehicle)))
            (increase (time) (* (distance ?from ?to) (per-unit-distance-time ?vehicle)))
        )
    )

    (:action LoadResource
        :parameters (?res - resource ?loc - location ?vehicle - freight-vehicle)
        :precondition (and 
            (at ?vehicle ?loc)
            (> (stock ?loc ?res) 0)
        )
        :effect (and
            (increase (time) 60)
            (increase (total-cost) 1000)
            (increase (plan-length) 1)
            (when
                (<= (stock ?loc ?res) (capacity ?vehicle))
                (and
                    (increase (contains ?vehicle ?res) (stock ?loc ?res))
                    (decrease (capacity ?vehicle) (stock ?loc ?res))
                    (assign (stock ?loc ?res) 0)
                )
            )
            (when
                (> (stock ?loc ?res) (capacity ?vehicle))
                (and
                    (increase (contains ?vehicle ?res) (capacity ?vehicle))
                    (decrease (stock ?loc ?res) (capacity ?vehicle))
                    (assign (capacity ?vehicle) 0)
                )
            )
        )
    )

    (:action DeliverResource
        :parameters (?res - resource ?loc - affected-location ?vehicle - freight-vehicle)
        :precondition (and 
            (at ?vehicle ?loc)
            (> (contains ?vehicle ?res) 0)
            (< (stock ?loc ?res) (needs-resource ?loc ?res))
            (forall
                (?other_loc - affected-location)
                (or
                    (>= (priority ?loc) (priority ?other_loc))
                    (and
                        (< (priority ?loc) (priority ?other_loc))
                        (not (needs-rescue ?other_loc))
                        (not (needs-evacuation ?other_loc))
                        (not (needs-medical-support ?other_loc))
                    )
                )
            )
        )
        :effect (and
            (increase (time) 30)
            (increase (total-cost) 500)
            (increase (plan-length) 1)
            (when
                (<= (- (needs-resource ?loc ?res) (stock ?loc ?res)) (contains ?vehicle ?res))
                (and
                    (decrease (contains ?vehicle ?res) (- (needs-resource ?loc ?res) (stock ?loc ?res)))
                    (increase (capacity ?vehicle) (- (needs-resource ?loc ?res) (stock ?loc ?res)))
                    (assign (stock ?loc ?res) (needs-resource ?loc ?res))
                )
            )
            (when
                (> (- (needs-resource ?loc ?res) (stock ?loc ?res)) (contains ?vehicle ?res))
                (and
                    (increase (capacity ?vehicle) (contains ?vehicle ?res))
                    (increase (stock ?loc ?res) (contains ?vehicle ?res))
                    (assign (contains ?vehicle ?res) 0)
                )
            )
        )
    )
    
    (:action UnloadResource
        :parameters (?res - resource ?loc - location ?vehicle - freight-vehicle)
        :precondition (and 
            (at ?vehicle ?loc)
            (> (contains ?vehicle ?res) 0)
        )
        :effect (and
            (increase (time) 60)
            (increase (total-cost) 1000)
            (increase (plan-length) 1)
            (increase (stock ?loc ?res) (contains ?vehicle ?res))
            (increase (capacity ?vehicle) (contains ?vehicle ?res))
            (assign (contains ?vehicle ?res) 0)
        )
    )

    (:action DistributeResource
        :parameters (?res - resource ?loc - affected-location)
        :precondition (and
            (> (needs-resource ?loc ?res) 0)
            (>= (stock ?loc ?res) (needs-resource ?loc ?res))
            (forall
                (?other_loc - affected-location)
                (or
                    (>= (priority ?loc) (priority ?other_loc))
                    (and
                        (< (priority ?loc) (priority ?other_loc))
                        (not (needs-rescue ?other_loc))
                        (not (needs-evacuation ?other_loc))
                        (not (needs-medical-support ?other_loc))
                    )
                )
            )
        )
        :effect (and
            (decrease (stock ?loc ?res) (needs-resource ?loc ?res))
            (increase (total-cost) (*(per-unit-distribution-cost ?res) (needs-resource ?loc ?res)))
            (assign (needs-resource ?loc ?res) 0)
            (increase (time) 60)
            (increase (plan-length) 1)
        )
    )

)
