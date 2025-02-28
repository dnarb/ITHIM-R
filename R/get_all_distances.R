#' Sequence to get distance data
#' 
#' Sequence of function calls to get distance data for modules from synthetic population
#' 
#' @param ithim_object list containing synthetic trip set
#' 
#' @return ithim_object again, with additional distance objects
#' 
#' @export
get_all_distances <- function(ithim_object){
  
  # add walk-to-bus trips, as appropriate, and combines list of scenarios
  #ithim_object$trip_scen_sets <- walk_to_pt_and_combine_scen()
  
  # Generate distance and duration matrices
  dist_and_dir <- dist_dur_tbls(ithim_object$trip_scen_sets)
  
  ithim_object$dist <- dist_and_dir$dist
  ithim_object$dur <- dist_and_dir$dur
  
  trip_scen_sets <- ithim_object$trip_scen_sets
  
  # find modal share
  mode_share_scen <- count(trip_scen_sets,scenario, trip_mode) %>% rename(count = n) # count by mode and scenario
  count_scenario <- count(trip_scen_sets,scenario) %>% rename(total_count = n) # find total number of trips per scenario
  mode_share_scen <- left_join(mode_share_scen, count_scenario, by = 'scenario') # merge data
  mode_share_scen$share <- mode_share_scen$count / mode_share_scen$total_count # calculate mode share
  mode_share_scen <- mode_share_scen %>% dplyr::select(-c(count, total_count)) # remove columns that aren't needed
  

  # Use demographic
  pop <- DEMOGRAPHIC
  
  # Rename col
  pop <- pop %>% dplyr::rename(age_cat = age)
  
  # trip_scen_sets <- io$delhi$trip_scen_sets
  # 
  # pop <- io$delhi$demographic
  
  total_synth_pop <- nrow(SYNTHETIC_POPULATION)
  
  # Recalculate dist by using total distance - using overall population
  dist <- trip_scen_sets %>% group_by(stage_mode, scenario) %>% 
    summarise(ave_dist = sum(stage_distance) / total_synth_pop * sum(pop$population)) %>% spread(scenario, ave_dist)

  if ('pedestrian' %in% dist$stage_mode && 'walk_to_pt' %in% dist$stage_mode){
    dist[dist$stage_mode == "pedestrian",][2:ncol(dist)] <- dist[dist$stage_mode == "pedestrian",][2:ncol(dist)] +
      dist[dist$stage_mode == "walk_to_pt",][2:ncol(dist)]

    dist <- dist %>% filter(stage_mode != 'walk_to_pt')
  }
  
  if (any(names(INJURY_TABLE) %in% 'whw')){
    if (any(unique(INJURY_TABLE$whw$strike_mode) %in% 'unknown')){
      
      temp <- dist[1,] %>% as.data.frame()
      temp[1,] <- c('unknown', rep(1, ncol(dist) - 1))
      
    }
    
  }
  
  ## for injury_function
  # get average total distances by sex and age cat
  # journeys <- trip_scen_sets %>% 
  #   group_by (age_cat,sex,stage_mode, scenario) %>% 
  #   summarise(tot_dist = sum(stage_distance) / total_synth_pop)
  # trip_scen_sets <- NULL
  # 
  # # Add population values by sex and age category
  # journeys <- dplyr::left_join(journeys, pop, by = c('sex', 'age_cat'))
  # 
  # # Calculate total distance by population
  # journeys$tot_dist <- journeys$tot_dist * journeys$population
  # 
  # # Remove additional population column
  # journeys <- journeys %>% dplyr::select(-population)
  
  # dist <- journeys %>% group_by(stage_mode, scenario) %>% summarise(dist = sum(tot_dist)) %>% spread(scenario, dist)
  # 
  # if ('walk_to_pt' %in% dist$stage_mode && 'walk_to_pt' %in% dist$stage_mode){
  #   dist[dist$stage_mode == "pedestrian",][2:ncol(dist)] <- dist[dist$stage_mode == "pedestrian",][2:ncol(dist)] +
  #     dist[dist$stage_mode == "pedestrian",][2:ncol(dist)]
  #   
  #   dist <- dist %>% filter(stage_mode != 'walk_to_pt')
  # }
  

  
  # find individual age / gender distances:
  trips_age_gender <- trip_scen_sets %>%
    group_by (age_cat,sex,stage_mode, scenario) %>%
    summarise(dist_age = sum(stage_distance))
  
  # find total trip distances by mode and scenario
  trips_scen_mode <- trip_scen_sets %>%
    group_by (stage_mode, scenario) %>%
    summarise(dist_synth = sum(stage_distance))

  trips_age_gender <- left_join(trips_age_gender, trips_scen_mode, by = c('stage_mode', 'scenario'))
  
  # find proportion of total trip distance in each age and gender category
  trips_age_gender$prop <- trips_age_gender$dist_age / trips_age_gender$dist_synth
  
  # find total distance across entire population (and not just synthetic pop)
  trips_age_gender$tot_dist <- trips_age_gender$dist_synth / total_synth_pop * sum(pop$population)
  
  # scale total distance by trip proportion for each age and gender
  trips_age_gender$tot_dist <- trips_age_gender$tot_dist * trips_age_gender$prop
 
  
  journeys <- trips_age_gender %>% dplyr::select(-c(dist_age, dist_synth, prop))
  
  
  # Add true_dist to the ithim_object
  ithim_object$true_dist <- dist
  
  #dist2 <- journeys %>% group_by(stage_mode, scenario) %>% summarise(total_dist = sum(tot_dist))
  
  # distances for injuries calculation
  ithim_object$inj_distances <- distances_for_injury_function(journeys = journeys, dist = dist,  mode_share_scen =  mode_share_scen)
  return(ithim_object)
}
