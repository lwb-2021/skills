# fetch.nu - Fetch skills from GitHub repositories
# Usage: nu fetch.nu

def fetch-dir [repo: string, path: string, target: string] {
    mkdir $target

    let result = (gh api $"repos/($repo)/contents/($path)" --jq "." | complete)
    if $result.exit_code != 0 { return 0 }

    let items = ($result.stdout | from json)
    mut count = 0

    for item in $items {
        if $item.type == "file" {
            let file_url = $"https://raw.githubusercontent.com/($repo)/main/($path)/($item.name)"
            let dl = (curl -fsSL $file_url | complete)
            if $dl.exit_code == 0 {
                $dl.stdout | save --force $"($target)/($item.name)"
                $count += 1
            }
        } else if $item.type == "dir" {
            $count += (fetch-dir $repo $"($path)/($item.name)" $"($target)/($item.name)")
        }
    }

    $count
}

def main [] {
    let config_path = $"($env.PWD)/skills.yaml"
    let skills_dir = $"($env.PWD)/skills"

    if not ($config_path | path exists) {
        error make { msg: $"Config not found: ($config_path)" }
    }

    rm -rf $skills_dir

    let config = open $config_path
    let skills = $config.skills | default {}

    mut skill_count = 0
    mut fail_count = 0

    for skill_name in ($skills | columns) {
        let repo = $skills | get $skill_name
        let path = $"skills/($skill_name)"
        let target_dir = $"($skills_dir)/($skill_name)"

        print $"(ansi green)[INFO](ansi reset) Fetching: ($skill_name) ($repo)"

        let downloaded = (fetch-dir $repo $path $target_dir)

        if $downloaded == 0 {
            print $"(ansi yellow)[WARN](ansi reset)  No files downloaded"
            rm -rf $target_dir
            $fail_count += 1
        } else {
            print $"  Downloaded ($downloaded) files"
            $skill_count += 1
        }
    }

    print ""
    print $"(ansi green)[INFO](ansi reset) Done! Fetched ($skill_count) skills ($fail_count) failed"
    print $"(ansi green)[INFO](ansi reset) Skills: ($skills_dir)"
}
