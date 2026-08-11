install.packages("tidyverse")
library(tidyverse)library(tidyverse)

library(tidyverse)


install.packages("tidyverse", dependencies = TRUE)


install.packages("ggplot2")
install.packages("dplyr")
install.packages("readr")

library(ggplot2)
library(dplyr)
library(readr)


dim_installation <- read_csv("dim_installation.csv")


setwd("C:/Users/anace/OneDrive/Escritorio/CV_NEW/PORTFAOLIO/quebec/csv")

getwd()


dim_region <- read_csv("dim_region.csv")
dim_installation <- read_csv("dim_installation.csv")
fact_ed_daily <- read_csv("fact_ed_daily.csv")

glimpse(fact_ed_daily)

summary(fact_ed_daily$value)

fact_ed_daily %>%
  group_by(metric) %>%
  summarise(
    min = min(value, na.rm = TRUE),
    mean = round(mean(value, na.rm = TRUE), 1),
    median = median(value, na.rm = TRUE),
    max = max(value, na.rm = TRUE)
  )


fact_ed_daily %>% 
  filter(metric == "taux_occupation", value == max(value, na.rm = TRUE))


fact_ed_daily %>%
  filter(metric == "taux_occupation") %>%
  slice_max(value, n = 1)


dim_installation %>% filter(installation_id == 55)


install.packages("farver")

library(ggplot2)

fact_ed_daily %>%
  filter(metric == "patients_sur_civiere", is_region_total == 0) %>%
  ggplot(aes(x = "", y = value)) +
  geom_boxplot() +
  labs(
    title = "Distribution of patients by Stretcher by Hospital ",
    subtitle = "Quebec, week  20-26 July 2026",
    x = "",
    y = "Patients in Stretcher"
  )

fact_ed_daily %>%
  filter(metric == "patients_sur_civiere", is_region_total == 0) %>%
  left_join(dim_installation, by = "installation_id") %>%
  left_join(dim_region, by = "region_code") %>%
  ggplot(aes(x = reorder(region_name, value, median), y = value)) +
  geom_boxplot() +
  coord_flip() +
  labs(title = "Distribución de pacientes en camilla por región",
       x = "", y = "Pacientes en camilla")



fact_ed_daily %>%
  filter(metric == "patients_sur_civiere", is_region_total == 0) %>%
  ggplot(aes(x = value)) +
  geom_histogram(bins = 30)
