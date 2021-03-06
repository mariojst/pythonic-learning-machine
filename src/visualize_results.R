# Step 0: import packages.
require(readr)
require(reshape2)
require(ggplot2)
require(ggthemes)
require(magrittr)
require(dplyr)
# Step 0.1: set theme.
theme_set(theme_tufte() +
            theme(
              text = element_text(size = 32),
              legend.position = "bottom",
              legend.title = element_blank()
            )
          )
h = 8
w = 14

# Step 1: set working directory.
setwd("C://Users//Jan//Documents//GitHub//pythonic-learning-machine//data_sets")
input_folder = '06_formatted'
output_folder = '07_results'
# Step 2: list files in wd.
folders = list.files(input_folder)
# Step 3: for folder in folders, read files.
load_tables = function(folders) {
  tables = list()
  for(folder in folders) {
    tables[[folder]] = list()
    files = list.files(file.path(input_folder, folder))
    for(file in files) {
      name = gsub(".csv", "", file)
      tables[[folder]][[name]] = read_csv(file.path(input_folder, folder, file))
    }
  }
  return(tables)
}

tables = load_tables(folders)

filter_ensemble <- function(tbl, include=T) {
  ensemble_names = c('RF', 'SLM (Ensemble)')
  filter = colnames(tbl) %in% ensemble_names
  if(!include) {
    filter = !filter
  }
  filter[1] = T
  tbl[, filter]
}

format_to_long <- function(tbl) {
  melt(tbl, id.vars = c("X1"))
}

draw_boxplot <- function(tbl, y_label='RMSE') {
  ggplot(tbl, aes(x=variable, y=value)) +
    geom_boxplot(size = 0.2, outlier.size = 0.2) +
    labs(
      y = y_label
    ) +
    theme(
      axis.title.x = element_blank()
    )
}

draw_lineplot <- function(tbl, y_label='RMSE') {
  ggplot(data=tbl, aes(x=X1, y=mean, ymin=mean-se, ymax=mean+se)) +
    geom_ribbon(aes(fill=variable), alpha=0.25) +
    geom_line(aes(colour=variable, linetype=variable)) +
    scale_linetype_manual(values = c("longdash", "dotted", "solid")) +
    labs(
      x = 'Epoch',
      y = y_label
    ) # +
    # theme(
    #   legend.position = 'None'
    # )
}

save_plot <- function(plot, f_name, f_path) {
  dir.create(f_path, showWarnings = FALSE)
  ggsave(plot, file = f_name, path = f_path, width = w, height = h)
}

process_boxplot <- function(tbl, f_name, f_path) {
  tbl %>% filter_ensemble(include=F) %>% format_to_long() %>% draw_boxplot() %>% save_plot(f_name=paste0(f_name, '.pdf'), f_path = file.path(output_folder, f_path))
  tbl %>% filter_ensemble(include=T) %>% format_to_long() %>% draw_boxplot() %>% save_plot(f_name=paste0(f_name, '_ens.pdf'), f_path = file.path(output_folder, f_path))
}

process_lineplot <- function(tbl_mean, tbl_se, f_name, f_path) {
  tbl_mean_long = tbl_mean %>% format_to_long()
  tbl_se_long = tbl_se %>% format_to_long()
  
  tbl = data.frame(X1 = tbl_mean_long$X1, variable = tbl_mean_long$variable, mean = tbl_mean_long$value, se = tbl_se_long$value)
  tbl %>% draw_lineplot() %>% save_plot(f_name=paste0(f_name, '.pdf'), f_path = file.path(output_folder, f_path))
}

process_tables <- function(tables, f_path) {
  tables$training_value %>% process_boxplot(f_name = 'training_value', f_path = f_path)
  tables$testing_value %>% process_boxplot(f_name = 'testing_value', f_path = f_path)
  process_lineplot(tables$training_value_evolution_mean, tables$training_value_evolution_se, f_name = 'training_value_evolution', f_path = f_path)
  process_lineplot(tables$testing_value_evolution_mean, tables$testing_value_evolution_se, f_name = 'testing_value_evolution', f_path = f_path)
}


remove_first_column <-function(tbl) {
  tbl[,-1]
}

calculate_p_values = function(tbl, ens_include = F) {
  
  tbl = remove_first_column(tbl)
  tbl = filter_ensemble(tbl, include = ens_include)
  if (ens_include) {
    slm_col = "SLM (Ensemble)"
  }
  else {
    slm_col = "SLM (OLS)"
  }
  sapply(tbl %>% select(-one_of(slm_col)), function(x) {
    w_test = wilcox.test(tbl %>% pull(one_of(slm_col)), x, paired = T, exact = F, alternative = "less")
    w_test$p.value
  })
}

calculate_mean_value = function(tbl) {
  
  tbl = remove_first_column(tbl)
  sapply(tbl, mean)
}


p_values = sapply(tables, function(x) {
  table = x$testing_value
  calculate_p_values(table)
})

p_values= t(p_values)

hidden_neurons = sapply(tables, function(x) {
  tbl = x$number_neurons
  calculate_mean_value(tbl)
})

hidden_neurons = t(hidden_neurons)


processing_time = sapply(tables, function(x) {
  tbl = x$processing_time
  calculate_mean_value(tbl)
})

processing_time = t(processing_time)

for (name in names(tables)) {
  tbl = tables[[name]]
  process_tables(tbl, name)
}

p_values_ens = sapply(tables, function(x) {
  tbl = x$testing_value %>% filter_ensemble() %>% remove_first_column()
  w_test = wilcox.test(tbl$`SLM (Ensemble)`, tbl$RF, paired = T, exact = F, alternative = "less")
  w_test$p.value
})
