package main

import (
	"bufio"
	"encoding/base64"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	csprojInSolutionPattern  = "Project\\(\"[^\"]*\"\\)\\s*=\\s*\"[^\"]*\",\\s*\"([^\"]*.csproj)\""
	unifiedXamarinIosAPIName = "Xamarin.iOS"
	monotouchAPIName         = "monotouch"
)

// SchemeModel ...
type SchemeModel struct {
	Configuration string
	Platform      string
}

// XamarinIosProjectModel ...
type XamarinIosProjectModel struct {
	Path    string
	ID      string
	APIName string
}

// SolutionModel ...
type SolutionModel struct {
	Path     string
	Projects []XamarinIosProjectModel
	Schemes  []SchemeModel
}

// Equal ...
func (scheme SchemeModel) Equal(otherScheme SchemeModel) bool {
	return ((scheme.Configuration == otherScheme.Configuration) && (scheme.Platform == otherScheme.Platform))
}

func containsScheme(schemes []SchemeModel, scheme SchemeModel) bool {
	for _, sch := range schemes {
		if sch.Equal(scheme) {
			return true
		}
	}
	return false
}

// ReferenceModel ...
type ReferenceModel struct {
	Include string `xml:"Include,attr"`
}

// ItemGroup ...
type ItemGroup struct {
	Reference []ReferenceModel `xml:"Reference"`
}

// ProjectModel ...
type ProjectModel struct {
	ItemGroups []ItemGroup `xml:"ItemGroup"`
}

func (project ProjectModel) String() string {
	ret := "Project:\n"
	ret += " PropertyGroups:\n"
	if len(project.ItemGroups) > 0 {
		ret += " ItemGroups:\n"
		for _, itemGroup := range project.ItemGroups {
			if len(itemGroup.Reference) > 0 {
				ret += "  ItemGroup:\n"
				for _, reference := range itemGroup.Reference {
					if reference.Include != "" {
						ret += "    Include: " + reference.Include + "\n"
					}
				}
				ret += "\n"
			}
		}
	}
	return ret
}

func getSolutionFiles() ([]string, error) {
	solutions := []string{}
	err := filepath.Walk(".", func(pth string, f os.FileInfo, err error) error {
		// if strings.Contains(pth, "Components/") || strings.Contains(pth, "Dependencies/") {
		// 	return nil
		// }
		if match, err := regexp.MatchString("(.*).sln", pth); err != nil {
			return err
		} else if match {
			solutions = append(solutions, pth)
		}
		return nil
	})

	return solutions, err
}

func getProjectIDPathMap(solutionFilePth string) (map[string]string, error) {
	bytes, err := ioutil.ReadFile(solutionFilePth)
	if err != nil {
		return map[string]string{}, err
	}
	content := string(bytes)

	reader := strings.NewReader(content)
	scanner := bufio.NewScanner(reader)

	solutionBasePth, _ := path.Split(solutionFilePth)
	projectPathIDMap := map[string]string{}
	for scanner.Scan() {
		lineStr := scanner.Text()

		if match, err := regexp.MatchString(csprojInSolutionPattern, lineStr); err != nil {
			return map[string]string{}, err
		} else if match {
			projectLineSlice := strings.Split(lineStr, ", ")

			if len(projectLineSlice) == 3 {
				projectPth := projectLineSlice[1]
				if strings.HasPrefix(projectPth, "\"") {
					projectPth = strings.TrimPrefix(projectPth, "\"")
				}
				if strings.HasSuffix(projectPth, "\"") {
					projectPth = strings.TrimSuffix(projectPth, "\"")
				}
				projectPth = strings.Replace(projectPth, "\\", "/", -1)
				projectPth = path.Join(solutionBasePth, projectPth)

				projectID := projectLineSlice[2]
				if strings.HasPrefix(projectID, " ") {
					projectID = strings.TrimPrefix(projectID, " ")
				}
				if strings.HasPrefix(projectID, "\"") {
					projectID = strings.TrimPrefix(projectID, "\"")
				}
				if strings.HasSuffix(projectID, "\"") {
					projectID = strings.TrimSuffix(projectID, "\"")
				}

				projectPathIDMap[projectID] = projectPth
			}
		}
	}

	return projectPathIDMap, nil
}

func getXamarinIosAPIName(projectPth string) string {
	bytes, err := ioutil.ReadFile(projectPth)
	if err != nil {
		return ""
	}

	projectConfigs := ProjectModel{}
	if err := xml.Unmarshal(bytes, &projectConfigs); err != nil {
		return ""
	}

	for _, itemGroup := range projectConfigs.ItemGroups {
		for _, reference := range itemGroup.Reference {
			if reference.Include == unifiedXamarinIosAPIName {
				return unifiedXamarinIosAPIName
			} else if reference.Include == monotouchAPIName {
				return monotouchAPIName
			}
		}
	}

	return ""
}

func getXamarinIosSchemes(solutionFilePth string) ([]SchemeModel, error) {
	bytes, err := ioutil.ReadFile(solutionFilePth)
	if err != nil {
		return []SchemeModel{}, err
	}
	content := string(bytes)

	reader := strings.NewReader(content)
	scanner := bufio.NewScanner(reader)

	solutionSchemes := []SchemeModel{}
	isNextLineSolutionConfiguration := false

	for scanner.Scan() {
		lineStr := scanner.Text()

		if strings.Contains(lineStr, "GlobalSection(SolutionConfigurationPlatforms) = preSolution") {
			isNextLineSolutionConfiguration = true
			continue
		} else if strings.Contains(lineStr, "EndGlobalSection") && isNextLineSolutionConfiguration {
			isNextLineSolutionConfiguration = false
			continue
		}

		if isNextLineSolutionConfiguration {
			lineSplits := strings.Split(lineStr, " = ")
			if len(lineSplits) == 2 {
				configComposit := lineSplits[1]
				configSplits := strings.Split(configComposit, "|")
				config := configSplits[0]
				platform := configSplits[1]

				scheme := SchemeModel{
					Configuration: config,
					Platform:      platform,
				}

				if containsScheme(solutionSchemes, scheme) == false {
					solutionSchemes = append(solutionSchemes, scheme)
				}
			}
		}
	}

	return solutionSchemes, nil
}

func writeProjectsToFile(branch string, solutions []SolutionModel) error {
	content := ""
	for _, solution := range solutions {
		branchBase64Str := base64.StdEncoding.EncodeToString([]byte(branch))
		solutionPathBase64 := base64.StdEncoding.EncodeToString([]byte(solution.Path))

		schemesBase64Str := ""
		for _, scheme := range solution.Schemes {
			scheme := base64.StdEncoding.EncodeToString([]byte(scheme.Configuration + "|" + scheme.Platform))
			schemesBase64Str = schemesBase64Str + "," + scheme
		}
		content = content + branchBase64Str + "," + solutionPathBase64 + "," + schemesBase64Str + "\n"
	}

	home := UserHomeDir()
	schemesPth := path.Join(home, ".schemes")
	return WriteStringToFile(schemesPth, content)
}

func main() {
	branch := os.Getenv("__BRANCH__")
	fmt.Printf("\nBranch: %s\n", branch)

	// Collect solution files
	solutionPths, err := getSolutionFiles()
	if err != nil {
		log.Fatalf("Failed to get solution file path, err: %s", err)
	}

	// Collect project files from solution files
	solutions := []SolutionModel{}
	for _, solutionFilePth := range solutionPths {
		schemes, err := getXamarinIosSchemes(solutionFilePth)
		if err != nil {
			log.Fatalf("Failed to get schemes in solution (%s), err: %s", solutionFilePth, err)
		}

		projectIDPathMap, err := getProjectIDPathMap(solutionFilePth)
		if err != nil {
			log.Fatalf("Failed to get project file paths, err: %s", err)
		}

		xamarinIosProjectModels := []XamarinIosProjectModel{}
		for ID, projectPath := range projectIDPathMap {
			iOSAPIName := getXamarinIosAPIName(projectPath)
			if iOSAPIName != "" {
				xamarinIosProject := XamarinIosProjectModel{
					Path:    projectPath,
					ID:      ID,
					APIName: iOSAPIName,
				}
				xamarinIosProjectModels = append(xamarinIosProjectModels, xamarinIosProject)
			}
		}

		if len(xamarinIosProjectModels) > 0 {
			solution := SolutionModel{
				Path:     solutionFilePth,
				Projects: xamarinIosProjectModels,
				Schemes:  schemes,
			}
			solutions = append(solutions, solution)
		}
	}

	if len(solutions) == 0 {
		log.Fatal("No xamarin iOS project found")
	} else {
		fmt.Println()

		if branch != "" {
			if err := writeProjectsToFile(branch, solutions); err != nil {
				log.Fatalf("Faild to write solutions to file, err: %s", err)
			}
		}

		for _, solution := range solutions {
			fmt.Printf("(i) solution found at: %s\n", solution.Path)
			for _, project := range solution.Projects {
				fmt.Printf("(i) xamarin iOS project found at: %s\n", project.Path)
				fmt.Printf("    project ID: %s\n", project.ID)
				fmt.Printf("    iOS API name: %s\n", project.APIName)
			}
			fmt.Printf("    schemes: %v\n", solution.Schemes)
			fmt.Println()
		}
	}
}
