// Copyright (c) 2018, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
// 
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerina/test;
import ballerina/http;
import ballerina/uuid;
import ballerina/os;
import ballerina/mime;
import ballerina/lang.runtime;

configurable string testOrganizationName = os:getEnv("ORG_NAME");
configurable string testUserRepositoryName = os:getEnv("USER_REPO_NAME");
configurable string testTopicName = os:getEnv("TOPIC_NAME");
configurable string testGistName = os:getEnv("GIST_NAME");
configurable string testResourcePath = os:getEnv("RESOURCE_PATH");
configurable string testIssueAssignee = os:getEnv("ISSUE_ASSIGNEE");
configurable string testUsername = os:getEnv("GITHUB_USERNAME");
configurable string authToken = os:getEnv("ACCESS_TOKEN");

const REPO_BASE_URL = "https://api.github.com/repos/connector-ecosystem/github-connector/contents";
const REPO_FILE_PATH = "/src/db/resources/info1.txt";
const FEATURE_BRANCH = "feature/feature2";

ConnectionConfig gitHubConfig = {
    auth: {
        token: authToken
    }
};

Client githubClient = check new (gitHubConfig);

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetUser() returns error? {
    log:printInfo(" Testing githubClient -> getUser()");
    User response = check githubClient->getUser();
    test:assertEquals(response.login, testUsername, msg = "Failed getUser() funtion for authenticated user");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetUserWithGivenUsername() returns error? {
    log:printInfo("Testing githubClient -> getUser() with a given username");
    User response = check githubClient->getUser(testUsername);
    test:assertEquals(response.login, testUsername, msg = "Failed getUser() funtion for a given username");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetRepository() returns error? {
    log:printInfo("Testing githubClient -> getRepository()");
    Repository response = check githubClient->getRepository(testUsername, testUserRepositoryName);
    test:assertEquals(response.name, testUserRepositoryName, msg = "Failed testGetUserRepository()");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetRepositories() returns error? {
    log:printInfo("Testing githubClient -> getRepositories() for authenticated user");
    stream<Repository, Error?> response = check githubClient->getRepositories();
    test:assertTrue(response.next() is record {|Repository value;|},
                    msg = "Failed testGetRepositories() for authenticated user");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetRepositoriesOfGivenUser() returns error? {
    log:printInfo("Testing githubClient -> getRepositories() for a given user");
    stream<Repository, Error?> response = check githubClient->getRepositories(testUsername);
    test:assertTrue(response.next() is record {|Repository value;|},
                    msg = "Failed testGetRepositories() for a given user");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetRepositoriesOfGivenOrganization() returns error? {
    log:printInfo("Testing githubClient -> getRepositories() for a given organization");
    stream<Repository, Error?> response = check githubClient->getRepositories(testOrganizationName, true);
    test:assertTrue(response.next() is record {|Repository value;|},
                    msg = "Failed testGetRepositories() for a given organization");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetCollaborators() returns error? {
    log:printInfo("githubClient -> getCollaborators()");
    stream<User, Error?> response = check githubClient->getCollaborators(testUsername, testUserRepositoryName);
    test:assertTrue(response.next() is record {|User value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testgetBranches() returns error? {
    log:printInfo("githubClient -> getBranches()");
    stream<Branch, Error?> response = check githubClient->getBranches(testUsername, testUserRepositoryName);
    test:assertTrue(response.next() is record {|Branch value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: false // This test case have been disabled as this operation cannot be run continuosly without 
    // deleteRepository operation which is not yet supported by the GitHub GraphQL API.
}
function testCreateRepository() returns error? {
    log:printInfo("githubClient -> createRepository()");
    CreateRepositoryInput createRepositoryInput = {
        name: "ballerina-github-connector-test-repo",
        visibility: PUBLIC_REPOSITORY,
        description: "New Updated Description"
    };
    check githubClient->createRepository(createRepositoryInput);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testUpdateRepository() returns error? {
    log:printInfo("githubClient -> updateRepository()");
    UpdateRepositoryInput updateRepositoryInput = {
        description: "New Updated Description"
    };
    check githubClient->updateRepository(updateRepositoryInput, testUsername, testUserRepositoryName);
}

string milestoneId = "";

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetMilestone() returns error? {
    log:printInfo("githubClient -> getMilestone()");
    Milestone milestone = check githubClient->getMilestone(testUsername, testUserRepositoryName, 2);
    test:assertTrue(milestone.number == 2, msg = "Failed testgetMilestones()");
    milestoneId = milestone.id;
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetMilestones() returns error? {
    log:printInfo("githubClient -> getMilestones()");
    stream<Milestone, Error?> response = check githubClient->getMilestones(testUsername, testUserRepositoryName);
    test:assertTrue(response.next() is record {|Milestone value;|});
}

string createdProjectId = "";
int createdProjectNumber = -1;
int getProjectRetryCount = 0;

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testCreateUserProject() returns error? {
    log:printInfo("githubClient -> createProject()");
    CreateRepositoryProjectInput createRepositoryProjectInput = {
        ownerName: testUsername,
        name: "Test Project Created by Ballerina GitHub Connector",
        body: "This is the body of the test project"
    };
    Project response = check githubClient->createProject(createRepositoryProjectInput);
    createdProjectId = response.id;
    createdProjectNumber = (<int>(response?.number));
}

string createdIssueId = "";
int createdIssueNumber = -1;

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testGetMilestone, testCreateUserProject]
}
function testCreateIssue() returns error? {
    log:printInfo("githubClient -> createIssue()");
    CreateIssueInput createIssueInput = {
        title: "This is a test Issue Title",
        body: "This is test issue body",
        labelNames: ["bug"],
        assigneeNames: [testUsername],
        projectIds: [createdProjectId],
        milestoneId: milestoneId
    };

    Issue|Error response =  githubClient->createIssue(createIssueInput, testUsername, testUserRepositoryName);
    if response is ClientError {
        record {|anydata body?;|} errorDetails = response.detail();
        log:printError("Client error received. Error detail = " + errorDetails?.body.toString());
        return response;
    } else if response is ServerError {
        record {|json? data?; GraphQLClientError[] errors; map<json>? extensions?;|} errorDetails = response.detail();
        log:printError("Server error received. Error detail = " + errorDetails.errors.toString());
        return response;
    } else {
        createdIssueId = response.id;
        createdIssueNumber = response.number;
    }

}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreateIssue]
}
function testUpdateIssue() returns error? {
    log:printInfo("githubClient -> updateIssue()");
    UpdateIssueInput updateRepositoryInput = {
        title: "Updated issue title",
        body: "This is updated test issue body",
        labelNames: ["enhancement"],
        assigneeNames: [testUsername],
        milestoneId: milestoneId
    };

    Issue response = check githubClient->updateIssue(updateRepositoryInput, testUsername, testUserRepositoryName, createdIssueNumber);
    log:printInfo("Issue updated: " + response.toString());
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreateIssue]
}
function testGetIssue() returns error? {
    log:printInfo("githubClient -> getIssue()");
    Issue response = check githubClient->getIssue(testUsername, testUserRepositoryName, createdIssueNumber);
    test:assertTrue(response.number == createdIssueNumber, msg = "Failed testGetIssue()");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetIssues() returns error? {
    log:printInfo("githubClient -> getIssues()");
    IssueFilters issueFilters = {
        assignee: testUsername,
        labels: ["good first issue"]
    };
    stream<Issue, Error?> response = check githubClient->getIssues(testUsername, testUserRepositoryName, issueFilters);
    test:assertTrue(response.next() is record {|Issue value;|});
}

string createdIssueCommentId = "";

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreateIssue]
}
function testAddComment() returns error? {
    log:printInfo("githubClient -> addComment()");
    AddIssueCommentInput addIssueCommentInput = {
        repositoryOwnerName: testUsername,
        repositoryName: testUserRepositoryName,
        issueNumber: createdIssueNumber,
        body: "Comment Added by Ballerina GitHub connector!"
    };
    IssueComment response = check githubClient->addComment(addIssueCommentInput);
    createdIssueCommentId = response.id;
    log:printInfo("ID: " + response.id);
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testAddComment]
}
function testUpdateComment() returns error? {
    log:printInfo("githubClient -> updateComment()");
    UpdateIssueCommentInput updateIssueComment = {
        id: createdIssueCommentId,
        body: "new comment added with addComment() UPDATED"
    };
    check githubClient->updateComment(updateIssueComment);
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testUpdateComment]
}
function testDeleteComment() returns error? {
    log:printInfo("githubClient -> deleteComment()");
    DeleteIssueCommentInput deleteIssueComment = {
        id: createdIssueCommentId
    };
    check githubClient->deleteComment(deleteIssueComment);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetRepositoryLabel() returns error? {
    log:printInfo("githubClient -> getLabel()");
    string labelName = "bug";
    Label response = check githubClient->getLabel(testUsername, testUserRepositoryName, labelName);
    test:assertTrue(response.name == "bug", msg = "Failed testGetRepositoryLabel()");
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testAddLabelsToLabelable]
}
function testGetLabels() returns error? {
    log:printInfo("githubClient -> getLabels()");
    stream<Label, Error?> response = check githubClient->getLabels(testUsername, testUserRepositoryName, createdIssueNumber);
    test:assertTrue(response.next() is record {|Label value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreateIssue]
}
function testAddLabelsToLabelable() returns error? {
    log:printInfo("githubClient -> addIssueLabel()");
    AddLabelsInput addIssueLabelInput = {
        repositoryOwnerName: testUsername,
        repositoryName: testUserRepositoryName,
        issueNumber: createdIssueNumber,
        labelNames: ["bug"]
    };
    LabelList response = check githubClient->addLabels(addIssueLabelInput);
    test:assertTrue(response.length() >= 0, msg = "Failed testGetRepositoryLabelListInIssue()");
    log:printInfo(response.toString());
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testAddLabelsToLabelable]
}
function testRemoveLabelsFromLabelable() returns error? {
    log:printInfo("githubClient -> removeLabel()");
    RemoveIssueLabelInput removeIssueLabelsInput = {
        repositoryOwnerName: testUsername,
        repositoryName: testUserRepositoryName,
        issueNumber: createdIssueNumber,
        labelNames: ["bug"]
    };
    check githubClient->removeLabel(removeIssueLabelsInput);
}

string createdPullRequestId = "";
int createdPullRequestNumber = -1;

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testCreatePullRequest() returns error? {
    log:printInfo("githubClient -> createPullRequest()");
    //push some changes to the branch before creating PR (Github limitation) 
    check updateFeatureRepository();
    CreatePullRequestInput createPullRequestInput = {
        title: "Test PR created from Ballerina GitHub Connector",
        baseRefName: "master",
        headRefName: FEATURE_BRANCH,
        body: "This is some dummy content for PR body"
    };
    PullRequest response = check githubClient->createPullRequest(createPullRequestInput, testUsername, testUserRepositoryName);
    createdPullRequestId = response.id;
    createdPullRequestNumber = (<int>(response?.number));
}

function updateFeatureRepository() returns error? {
    http:BearerTokenConfig tokenConfig = {token: authToken};
    http:ClientConfiguration httpClientConfig = {auth: tokenConfig};
    http:Client githubDirectClient = check new (REPO_BASE_URL, httpClientConfig);
    map<string> fileAPIHeaders = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"};

    //get sha of existing file
    json fileInfo = check githubDirectClient->get(REPO_FILE_PATH + "?ref=" + FEATURE_BRANCH, fileAPIHeaders);
    string sha = check fileInfo.sha;
    log:printInfo("sha of file = " + sha);

    //update the file
    http:Request updateFileRequest = new ();
    string fileContent = "my new file contents=" + uuid:createType1AsString();
    string encordedFileContent = check mime:base64Encode(fileContent).ensureType();
    json payload = {
        "message": "Update file",
        "branch": FEATURE_BRANCH,
        "committer": {"name": "connector-ecosystem", "email": "connector.ecosystem@gmail.com"},
        "content": encordedFileContent,
        "sha": sha
    };
    updateFileRequest.setJsonPayload(payload);
    json _ = check githubDirectClient->put(REPO_FILE_PATH,updateFileRequest, fileAPIHeaders);
    log:printInfo("sucessfully updated file " + REPO_BASE_URL + REPO_FILE_PATH);

}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreatePullRequest]
}
function testGetPullRequest() returns error? {
    log:printInfo("githubClient -> getPullRequest()");
    PullRequest response = check githubClient->getPullRequest(testUsername, testUserRepositoryName, createdPullRequestNumber);
    test:assertTrue(response.number == createdPullRequestNumber, msg = "Failed testGetPullRequest()");
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testGetPullRequest]
}
function testLastCommit() returns error? {
    log:printInfo("Testing Last commit part from githubClient->getPullRequest");
    PullRequest pullRequest = check githubClient->getPullRequest(testUsername, testUserRepositoryName,
                                                                createdPullRequestNumber);
    test:assertTrue(pullRequest.lastCommit is Commit, "Issue in fetching last commit");
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetPullRequestList() returns error? {
    log:printInfo("githubClient -> getPullRequests()");
    stream<PullRequest, Error?> response = check githubClient->getPullRequests("ballerina-platform", "module-ballerinax-googleapis.gmail", PULL_REQUEST_MERGED);
    test:assertTrue(response.next() is record {|PullRequest value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testLastCommit]
}
function testUpdatePullRequest() returns error? {
    log:printInfo("githubClient -> updatePullRequest()");
    UpdatePullRequestInput updatePullRequestInput = {
        title: "Test PR created from Ballerina GitHub Connector Updated",
        labelNames: ["bug"],
        assigneeNames: ["MadhurangaWije"]
    };
    PullRequest response = check githubClient->updatePullRequest(updatePullRequestInput, testUsername, testUserRepositoryName, createdPullRequestNumber);
    log:printInfo(response.toString());
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testUpdatePullRequest]
}
function testUpdatePullRequestToClose() returns error? {
    log:printInfo("githubClient -> updatePullRequest()");
    UpdatePullRequestInput updatePullRequestInput = {
        state: PULL_REQUEST_CLOSED
    };

    PullRequest response = check githubClient->updatePullRequest(updatePullRequestInput, testUsername, testUserRepositoryName, createdPullRequestNumber);
    log:printInfo(response.toString());
}

string createdPullRequestReviewId = "";
string createdPullRequestReviewIdWithPendingState = "";

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testUpdatePullRequest]
}
function testCreatePullRequestReview() returns error? {
    log:printInfo("githubClient -> createPullRequestReview()");
    AddPullRequestReviewInput createPullRequestReviewInput = {
        body: "This is a test review comment for a pull  from Ballerina GitHub connector ",
        event: PULL_REQUEST_REVIEW_COMMENT
    };

    PullRequestReview response = check githubClient->createPullRequestReview(createPullRequestReviewInput, testUsername, testUserRepositoryName, createdPullRequestNumber);
    createdPullRequestReviewId = response.id;
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testUpdatePullRequest]
}
function testCreatePullRequestReviewWithPendingState() returns error? {
    log:printInfo("githubClient -> createPullRequestReview()");
    AddPullRequestReviewInput createPullRequestReviewInput = {
        body: "This is a test review comment for a pull  from Ballerina GitHub connector "
    };

    PullRequestReview response = check githubClient->createPullRequestReview(createPullRequestReviewInput, testUsername, testUserRepositoryName, createdPullRequestNumber);
    createdPullRequestReviewIdWithPendingState = response.id;
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreatePullRequestReview]
}
function testUpdatePullRequestReview() returns error? {
    log:printInfo("githubClient -> updatePullRequestReview()");
    UpdatePullRequestReviewInput updatePullRequestReviewInput = {
        pullRequestReviewId: createdPullRequestReviewId,
        body: "This is a test review comment for a pull  from Ballerina GitHub connector Updated"
    };
    check githubClient->updatePullRequestReview(updatePullRequestReviewInput);
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreatePullRequestReviewWithPendingState]
}
function testDeletePullRequestReview() returns error? {
    log:printInfo("githubClient -> deletePendingPullRequestReview()");
    DeletePullRequestReviewInput deletePullRequestReview = {
        pullRequestReviewId: createdPullRequestReviewIdWithPendingState
    };
    check githubClient->deletePendingPullRequestReview(deletePullRequestReview);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetOrgProjectList() returns error? {
    log:printInfo("githubClient -> getOrganizationProjectList()");
    stream<Project, Error?> response = check githubClient->getProjects("wso2-enterprise", GITHUB_ORGANIZATION, (), PROJECT_OPEN);
    test:assertTrue(response.next() is record {|Project value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testCreateUserProject]
}
function testGetUserProject() returns error? {
    log:printInfo("githubClient -> getProject()");
    getProjectRetryCount = getProjectRetryCount + 1;
    Project|Error project = githubClient->getProject(testUsername, createdProjectNumber);
    if project is ClientError {
        record {|anydata body?;|} errorDetails = project.detail();
        log:printError("Client error received. Error detail = " + errorDetails?.body.toString());
        if(getProjectRetryCount > 3) {
            return project;
        } else {
            log:printInfo("Retrying githubClient -> getProject() after 5 seconds...");
            runtime:sleep(5);   //Github seems to add project async mannger. Sometimes immediate call does not return the project.
            return testGetUserProject();
        }     
    } else if project is ServerError {
        record {|json? data?; GraphQLClientError[] errors; map<json>? extensions?;|} errorDetails = project.detail();
        log:printError("Server error received. Error detail = " + errorDetails.errors.toString());
        return project;
    } else {
        log:printInfo(project.toString());
    }
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testGetUserProject]
}
function testUpdateProject() returns error? {
    log:printInfo("githubClient -> updateProject()");
    UpdateProjectInput updateProjectInput = {
        projectId: createdProjectId,
        name: "Test Project Created by Ballerina GitHub Connector UPDATED"
    };

    Project response = check githubClient->updateProject(updateProjectInput);
    log:printInfo(response.toString());
}

@test:Config {
    groups: ["network-calls"],
    enable: true,
    dependsOn: [testUpdateProject, testCreateIssue]
}
function testDeleteProject() returns error? {
    log:printInfo("githubClient -> deleteProject()");
    DeleteProjectInput deleteProjectInput = {
        projectId: createdProjectId
    };
    check githubClient->deleteProject(deleteProjectInput);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetRepositoryProjectList() returns error? {
    log:printInfo("githubClient -> getRepositoryProjectList()");
    stream<Project, Error?> response = check githubClient->getProjects(testUsername, GITHUB_USER, testUserRepositoryName, PROJECT_OPEN);
    test:assertTrue(response.next() is record {|Project value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetUserProjectList() returns error? {
    log:printInfo("githubClient -> getUserProjectList()");
    stream<Project, Error?> response = check githubClient->getProjects(testUsername, GITHUB_USER);
    test:assertTrue(response.next() is record {|Project value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetOrganization() returns error? {
    log:printInfo("githubClient -> getOrganization()");
    stream<Organization, Error?> response = check githubClient->getOrganizations(testOrganizationName, GITHUB_ORGANIZATION);
    test:assertTrue(response.next() is record {|Organization value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetUserOrganizationList() returns error? {
    log:printInfo("githubClient -> getUserOrganizationList()");
    stream<Organization, Error?> response = check githubClient->getOrganizations("kasthuriraajan", GITHUB_USER);
    test:assertTrue(response.next() is record {|Organization value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testGetOrganizationMembersList() returns error? {
    log:printInfo("githubClient -> getOrganizationMembers()");
    stream<User, Error?> response = check githubClient->getOrganizationMembers("ballerina-platform");
    test:assertTrue(response.next() is record {|User value;|});
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearch() returns @tainted error? {
    log:printInfo("githubClient -> search()");
    SearchResult response = check githubClient->search("connector-", SEARCH_TYPE_USER, 10);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    test:assertTrue(result is User[]);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchMultiWordsString() returns error? {
    log:printInfo("githubClient -> testSearchMultiWordsString()");

    string query = string `repo:ballerina-platform/ballerina-extended-library is:issue is:open label:"Type/New Feature"`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_ISSUE, 10);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    test:assertTrue(result is Issue[]);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchIssueLabels() returns error? {
    log:printInfo("githubClient -> testSearchIssueLabels()");

    string query = string `repo:ballerina-platform/ballerina-extended-library is:issue is:open label:"Team/Connector"`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_ISSUE, 1, 1);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    if result is Issue[] {
        if result.length() > 0 {
            int labelCount = let var nodes = result[0]?.labels?.nodes
                in nodes is () ? 0 : nodes.length();
            test:assertTrue(labelCount == 1);
        }
    } else {
        test:assertFail("Incorrect search results");
    }
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchPullRequest() returns error? {
    log:printInfo("githubClient -> testSearchPullRequest()");

    string query = string `repo:ballerina-platform/ballerina-extended-library is:pr is:open`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_PULL_REQUEST, 10);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    test:assertTrue(result is PullRequest[]);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchPullRequestComplex() returns error? {
    log:printInfo("githubClient -> testSearchPullRequestComplex()");

    string query = string `repo:ballerina-platform/ballerina-extended-library is:pr state:closed author:abeykoon created:2021-11-01..2022-07-11`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_PULL_REQUEST, 5);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    test:assertTrue(result is PullRequest[]);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchPullRequestWithRelatedIssues() returns error? {
    log:printInfo("githubClient -> testSearchPullRequestWithRelatedIssues()");

    string query = string `repo:ballerina-platform/module-ballerinax-github is:pr is:closed author:sachinira`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_PULL_REQUEST, 5);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;

    if result is PullRequest[] {
        foreach PullRequest item in result {
            RelatedIssues issues = item?.closingIssuesReferences ?: {};
            if issues?.nodes != [] {
                Issue[] issueData = issues?.nodes ?: [];
                test:assertTrue(issueData != []);
            }
        }
    }
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchPullRequestWithReviews() returns error? {
    log:printInfo("githubClient -> testSearchPullRequestWithReviews()");

    string query = string `repo:ballerina-platform/module-ballerinax-github is:pr is:closed review:approved author:sachinira`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_PULL_REQUEST, 5, perPageCountForPRReviews = 1);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;

    if result is PullRequest[] {
        foreach PullRequest item in result {
            PullRequestReview[]? pullRequestReviews = item.pullRequestReviews;
            if pullRequestReviews is PullRequestReview[] {
                if pullRequestReviews.length() > 0 {
                    test:assertTrue(pullRequestReviews.length() == 1);
                }
            }
        }
    }
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchUser() returns error? {
    log:printInfo("githubClient -> testSearchUser()");

    string query = string `mike in:name created:<2022-01-01 type:user`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_USER, 20);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    test:assertTrue(result is User[]);
}

@test:Config {
    groups: ["network-calls"],
    enable: true
}
function testSearchOrganization() returns error? {
    log:printInfo("githubClient -> testSearchOrganization()");

    string query = string `data in:email type:org`;
    SearchResult response = check githubClient->search(query, SEARCH_TYPE_ORGANIZATION, 20);
    Issue[]|User[]|Organization[]|Repository[]|PullRequest[] result = response.results;
    test:assertTrue(result is Organization[]);
}

@test:Config {
    enable: true
}
function testGetLanguagesFromRepository() returns error? {
    log:printInfo("Testing language list in a given repository");
    Repository response = check githubClient->getRepository(testUsername, testUserRepositoryName);
    Language[]? languageList = response?.languages;
    if languageList is Language[] {
        test:assertTrue(languageList.length() > 0, "Failed to get language list");
    } else {
        test:assertFail("Language list is empty");
    }
}

@test:Config {
    enable: true
}
function testGetRepositoryContent() returns error? {
    log:printInfo("githubClient -> testGetRepositoryContent()");
    File[] response = check githubClient->getRepositoryContent(testUsername, testUserRepositoryName, "HEAD:");
    test:assertTrue(response.length() > 0, "Failed to get file list");
}

@test:Config {
    groups: ["network-calls"]
}
function testStarRepository() returns error? {
    log:printInfo("githubClient -> starRepository()");
    check githubClient->starRepository(testUsername, testUserRepositoryName);
}

@test:Config {
    groups: ["network-calls"],
    dependsOn: [testStarRepository]
}
function testUnstarRepository() returns error? {
    log:printInfo("githubClient -> unstarRepository()");
    check githubClient->unstarRepository(testUsername, testUserRepositoryName);
}

@test:Config {
    groups: ["network-calls"]
}
function testStarTopic() returns error? {
    log:printInfo("githubClient -> starTopic()");
    check githubClient->starTopic(testTopicName);
}

@test:Config {
    groups: ["network-calls"],
    dependsOn: [testStarTopic]
}
function testUnstarTopic() returns error? {
    log:printInfo("githubClient -> unstarTopic()");
    check githubClient->unstarTopic(testTopicName);
}

@test:Config {
    groups: ["network-calls"]
}
function testStarGist() returns error? {
    log:printInfo("githubClient -> starGist()");
    check githubClient->starGist(testUsername, testGistName);
}

@test:Config {
    groups: ["network-calls"],
    dependsOn: [testStarGist]
}
function testUnstarGist() returns error? {
    log:printInfo("githubClient -> unstarGist()");
    check githubClient->unstarGist(testUsername, testGistName);
}
