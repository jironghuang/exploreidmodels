#Load packages
source("load_packages.R")

## Stop spurious warnings
options(warn = -1)

shinyServer(function(input, output) {
  
  ## Set up reactive values
  simulations <- reactiveValues(current = NULL, previous = NULL)
  
  ## Declare fixed parameters
  N <- 1000
  I <- 1
  R <- 0
  
  model_sim <- eventReactive(input$go, {
  ##across all models
  times <- seq(0, input$maxtime, 0.1)
  
  ## Choose model and set up
    if (input$model %in% "SI_ode") {
      ## Model
      model <- ifelse(input$demographics, SI_demo_ode, SI_ode)
      sim_fn <- solve_ode
      ##parameters
      params <- data.frame(beta = input$beta)
      
      ##initial pop
      inits <- data.frame(S = N - I, I = I)
    }else if (input$model %in% "SEI_ode") {
      ## Model
      model <- ifelse(input$demographics, SEI_demo_ode, SEI_ode)
      sim_fn <- solve_ode
      ##parameters
      params <- data.frame(beta = input$beta, gamma = 12/input$gamma)
      
      ##initial pop
      inits <- data.frame(S = N - I, E = 0, I = I)
    }else if (input$model %in% "SEIR_ode") {
      ## Model
      model <- ifelse(input$demographics, SEIR_demo_ode, SEIR_ode)
      sim_fn <- solve_ode
      ##parameters
      params <- data.frame(beta = input$beta, gamma = 12/input$gamma, tau = 12/input$tau)
      
      ##initial pop
      inits <- data.frame(S = N - I, E = 0, I = I, R = R)
    }else if (input$model %in% "SHLIR_ode") {
      ## Model
      model <- ifelse(input$demographics, SHLIR_demo_ode, SHLIR_ode)
      sim_fn <- solve_ode
      ##parameters
      params <- data.frame(beta = input$beta, gamma_H = input$gamma_H, 
                           gamma_L = 1 / input$gamma_L, nu = 1 / input$nu, tau = 12 / input$tau)
      
      ##initial pop
      inits <- data.frame(S = N - I, H = 0, L = 0, I = I, R = R)
    }else if (input$model %in% "SHLITR_risk_group_ode") {
      
      ## Model
      model <- SHLITR_risk_group_ode
      sim_fn <- solve_ode
      ##parameters
      params <- data.frame(beta = input$beta, beta_H = input$beta_H, 
                           gamma_H = input$gamma_H, epsilon = 1 / input$epsilon,
                           gamma_L = 1 / input$gamma_L, nu = 1 / input$nu, 
                           tau = 12 / input$tau, mu = 1 / input$mu, p = input$prop_high, M = input$M)
      
      ##initial pop
      inits <- data.frame(S = (1 - params$p) * N, H = 0, L = 0, I = 0, Tr = 0, R = 0,
                          S_H = params$p * N - I, H_H = 0, L_H = 0, I_H = I, Tr_H = 0, R_H = 0)
    }
  
  ## Add demographics
  if (input$demographics) {
    params$mu = 1/input$mu
  }
  
  ## For rate parameters that have been made using time periods convert Inf to very large numbers
  params <- mutate_if(params, is.numeric, .funs = funs({ifelse(. %in% Inf, 1e10, .)}))
  
  ## Run model
    model_sim <- simulate_model(model = model, 
                                sim_fn = sim_fn, 
                                inits = inits, 
                                params = params,
                                times = times,
                                as_tibble = TRUE)
    
    models <- list(model_sim, model)
  }, ignoreNULL = FALSE)
  
  
  ## Store current model simulation and set previous as old simulation
  observeEvent(model_sim(), {simulations$previous <- simulations$current; simulations$current <- model_sim()})
           
  ## Check models are implemented
  model_implemented <- reactive({
    validate(
      need(!all(!input$demographics, input$model %in% "SHLITR_risk_group_ode"), "This model has only be implemented with demographics, enable them")
    )
    
    message("Model has been implemented, showing output.")
  })
  
  ## Previous model exists
  previous_model_exists <- reactive({
    validate(
      need(!all(is.null(simulations$previous), input$previous_model_run),
           "In order to compare models you must simulate a second model")
    )
    
    message("Two models have been simulated or a comparision is not needed.")
  })
  
  ## Plot model
  output$plot_model_traj <- renderPlotly({
    
    model_implemented()
    previous_model_exists()
    
    if (input$previous_model_run) {
      prev_sim <- simulations$previous[[1]]
    }else{
      prev_sim <- NULL
    }
    
    simulations$current[[1]] %>% 
      biddmodellingcourse::plot_model(
        prev_sim = prev_sim,
        facet = input$facet_model, interactive = TRUE)
  })
  
  ## Raw model table
  output$model_sim_results <- DT::renderDataTable({
    
    model_implemented()
    previous_model_exists()
    
    if (input$previous_model_run) {
      simulations$current[[1]] %>% 
        mutate(Model = "Current") %>% 
        bind_rows(simulations$previous[[1]] %>% 
                    mutate(Model = "Previous"))
    }else{
      simulations$current[[1]]
    }

  })
  
  ## Model summary table
  output$model_sum_tab <- renderTable({
    
    model_implemented()
    previous_model_exists()
    
    summary_tab <- simulations$current[[1]] %>% 
      biddmodellingcourse::summarise_model() %>% 
      mutate(Model = "Current")
    
    if (input$previous_model_run) {
      summary_tab <- summary_tab %>% 
        bind_rows(simulations$previous[[1]] %>% 
                    biddmodellingcourse::summarise_model() %>%
                    mutate(Model = "Previous"))
    }
    
    summary_tab %>% 
      select(Model, everything()) %>% 
      mutate_if(is.numeric, .funs = funs(round(., digits = 0))) %>% 
      mutate_if(is.numeric, .funs = as.integer)
  })
  
  
  ## Model code
  output$model_code <- renderPrint({
    
    model_implemented()
    
    print(simulations$current[[2]])
  })

  output$downloadData2 <- downloadHandler(filename = "ui.R",
                                          content = function(file) {
                                            file.copy("ui.R", file, overwrite = TRUE)
                                            }
                                          )
  output$downloadData3 <- downloadHandler(filename = "server.R",
                                          content = function(file) {
                                            file.copy("server.R", file, overwrite = TRUE)
                                            }
                                          )
  
})
